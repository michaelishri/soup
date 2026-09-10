using System.Globalization;
using Jellyfin.Plugin.Soup.Configuration;
using MediaBrowser.Common.Configuration;
using MediaBrowser.Common.Plugins;
using MediaBrowser.Model.Plugins;
using MediaBrowser.Model.Serialization;

namespace Jellyfin.Plugin.Soup;

/// <summary>
/// Soup entitlement mailbox plugin (Pattern A assertion exchange).
/// </summary>
public class Plugin : BasePlugin<PluginConfiguration>, IHasWebPages
{
    /// <summary>
    /// Stable plugin id (also used by the admin config page).
    /// </summary>
    public static readonly Guid PluginGuid = Guid.Parse("c8a7e6d5-4b3a-2918-07f6-e5d4c3b2a190");

    /// <summary>
    /// Initializes a new instance of the <see cref="Plugin"/> class.
    /// </summary>
    /// <param name="applicationPaths">Application paths.</param>
    /// <param name="xmlSerializer">XML serializer.</param>
    public Plugin(IApplicationPaths applicationPaths, IXmlSerializer xmlSerializer)
        : base(applicationPaths, xmlSerializer)
    {
        Instance = this;
    }

    /// <inheritdoc />
    public override string Name => "Soup Auth";

    /// <inheritdoc />
    public override string Description =>
        "Invite Google subjects, mint Tailscale guest auth keys into Soup, and exchange Soup assertions for Jellyfin sessions.";

    /// <inheritdoc />
    public override Guid Id => PluginGuid;

    /// <summary>
    /// Gets the live plugin instance.
    /// </summary>
    public static Plugin? Instance { get; private set; }

    /// <inheritdoc />
    public IEnumerable<PluginPageInfo> GetPages()
    {
        return
        [
            new PluginPageInfo
            {
                Name = Name,
                EmbeddedResourcePath = string.Format(
                    CultureInfo.InvariantCulture,
                    "{0}.Configuration.configPage.html",
                    GetType().Namespace)
            }
        ];
    }

    /// <summary>
    /// Persist configuration after in-memory mutation.
    /// </summary>
    public void Save()
    {
        SaveConfiguration();
    }
}
