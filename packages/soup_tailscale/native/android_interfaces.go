// Copyright (c) Tailscale Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"net"
	"net/netip"
	"os"
	"slices"
	"sync"

	"tailscale.com/net/netmon"
)

var soupAndroidInterfaces struct {
	sync.RWMutex
	value []netmon.Interface
}

//export SoupSetLogsDirectory
func SoupSetLogsDirectory(directory *C.char) C.int {
	if directory == nil {
		return -1
	}
	if err := os.Setenv("TS_LOGS_DIR", C.GoString(directory)); err != nil {
		return -1
	}
	return 0
}

type soupAddressJSON struct {
	IP        string `json:"ip"`
	PrefixLen int    `json:"prefixLen"`
}

type soupInterfaceJSON struct {
	Name      string            `json:"name"`
	Index     int               `json:"index"`
	MTU       int               `json:"mtu"`
	Up        bool              `json:"up"`
	Broadcast bool              `json:"broadcast"`
	Loopback  bool              `json:"loopback"`
	PointToPt bool              `json:"pointToPoint"`
	Multicast bool              `json:"multicast"`
	Addrs     []soupAddressJSON `json:"addrs"`
}

func init() {
	netmon.RegisterInterfaceGetter(func() ([]netmon.Interface, error) {
		soupAndroidInterfaces.RLock()
		defer soupAndroidInterfaces.RUnlock()
		return slices.Clone(soupAndroidInterfaces.value), nil
	})
}

//export SoupSetInterfaces
func SoupSetInterfaces(payload *C.char) C.int {
	if payload == nil {
		return -1
	}
	var input []soupInterfaceJSON
	if err := json.Unmarshal([]byte(C.GoString(payload)), &input); err != nil {
		return -1
	}
	output := make([]netmon.Interface, 0, len(input))
	for _, item := range input {
		if item.Name == "" {
			continue
		}
		iface := netmon.Interface{
			Interface: &net.Interface{Name: item.Name, Index: item.Index, MTU: item.MTU},
			AltAddrs:  []net.Addr{},
		}
		if item.Up {
			iface.Flags |= net.FlagUp
		}
		if item.Broadcast {
			iface.Flags |= net.FlagBroadcast
		}
		if item.Loopback {
			iface.Flags |= net.FlagLoopback
		}
		if item.PointToPt {
			iface.Flags |= net.FlagPointToPoint
		}
		if item.Multicast {
			iface.Flags |= net.FlagMulticast
		}
		for _, address := range item.Addrs {
			parsed, err := netip.ParseAddr(address.IP)
			if err != nil {
				continue
			}
			ip := net.IP(slices.Clone(parsed.AsSlice()))
			if zone := parsed.Zone(); zone != "" {
				iface.AltAddrs = append(iface.AltAddrs, &net.IPAddr{IP: ip, Zone: zone})
				continue
			}
			bits := 128
			if parsed.Is4() {
				bits = 32
			}
			if address.PrefixLen < 0 || address.PrefixLen > bits {
				iface.AltAddrs = append(iface.AltAddrs, &net.IPAddr{IP: ip})
				continue
			}
			iface.AltAddrs = append(iface.AltAddrs, &net.IPNet{
				IP: ip, Mask: net.CIDRMask(address.PrefixLen, bits),
			})
		}
		output = append(output, iface)
	}
	soupAndroidInterfaces.Lock()
	soupAndroidInterfaces.value = output
	soupAndroidInterfaces.Unlock()
	return 0
}
