using Microsoft.Owin;
using Owin;

[assembly: OwinStartupAttribute(typeof(AzureVMDemo.Startup))]
namespace AzureVMDemo
{
    public partial class Startup
    {
        public void Configuration(IAppBuilder app)
        {
            ConfigureAuth(app);
        }
    }
}
