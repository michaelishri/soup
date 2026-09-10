using MediaBrowser.Controller;
using MediaBrowser.Controller.Plugins;
using Microsoft.Extensions.DependencyInjection;
using Jellyfin.Plugin.Soup.Services;

namespace Jellyfin.Plugin.Soup;

/// <summary>
/// Registers plugin services into Jellyfin DI.
/// </summary>
public class PluginServiceRegistrator : IPluginServiceRegistrator
{
    /// <inheritdoc />
    public void RegisterServices(IServiceCollection serviceCollection, IServerApplicationHost applicationHost)
    {
        serviceCollection.AddHttpClient(SoupApiClient.HttpClientName);
        serviceCollection.AddHttpClient(TailscaleApiClient.HttpClientName);
        serviceCollection.AddSingleton<SoupApiClient>();
        serviceCollection.AddSingleton<TailscaleApiClient>();
        serviceCollection.AddSingleton<AssertionVerifier>();
        serviceCollection.AddSingleton<EntitlementService>();
        serviceCollection.AddSingleton<UserLinkService>();
    }
}
