{ shb }:
{
  testHomepageAsServiceGroup = {
    expected = [
      {
        "Media" = [
          {
            "Jellyfin" = {
              "href" = "https://example.com/jellyfin";
              "icon" = "sh-jellyfin";
              "siteMonitor" = "http://127.0.0.1:8096";
            };
          }
        ];
      }
    ];

    expr = shb.homepage.asServiceGroup {
      Media = {
        services = {
          Jellyfin = {
            dashboard.request = {
              externalUrl = "https://example.com/jellyfin";
              internalUrl = "http://127.0.0.1:8096";
            };
            apiKey = null;
          };
        };
      };
    };
  };

  testHomepageAsServiceGroupApiKey = {
    expected = [
      {
        "Media" = [
          {
            "Jellyfin" = {
              "href" = "https://example.com/jellyfin";
              "icon" = "sh-jellyfin";
              "siteMonitor" = "http://127.0.0.1:8096";
              "widget" = {
                "key" = "{{HOMEPAGE_FILE_Media_Jellyfin}}";
                "password" = "{{HOMEPAGE_FILE_Media_Jellyfin}}";
                "type" = "jellyfin";
                "url" = "http://127.0.0.1:8096";
              };
            };
          }
        ];
      }
    ];

    expr = shb.homepage.asServiceGroup {
      Media = {
        services = {
          Jellyfin = {
            dashboard.request = {
              externalUrl = "https://example.com/jellyfin";
              internalUrl = "http://127.0.0.1:8096";
            };
            apiKey.result.path = "path_D";
          };
        };
      };
    };
  };

  testHomepageAsServiceGroupNoServiceMonitor = {
    expected = [
      {
        "Media" = [
          {
            "Jellyfin" = {
              "href" = "https://example.com/jellyfin";
              "icon" = "sh-jellyfin";
              "siteMonitor" = null;
            };
          }
        ];
      }
    ];

    expr = shb.homepage.asServiceGroup {
      Media = {
        services = {
          Jellyfin = {
            dashboard.request = {
              externalUrl = "https://example.com/jellyfin";
              internalUrl = null;
            };
            apiKey = null;
          };
        };
      };
    };
  };

  testHomepageAsServiceGroupOverride = {
    expected = [
      {
        "Media" = [
          {
            "Jellyfin" = {
              "href" = "https://example.com/jellyfin";
              "icon" = "sh-icon";
              "siteMonitor" = "http://127.0.0.1:8096";
            };
          }
        ];
      }
    ];

    expr = shb.homepage.asServiceGroup {
      Media = {
        services = {
          Jellyfin = {
            dashboard.request = {
              externalUrl = "https://example.com/jellyfin";
              internalUrl = "http://127.0.0.1:8096";
            };
            settings = {
              icon = "sh-icon";
            };
            apiKey = null;
          };
        };
      };
    };
  };

  testHomepageAsServiceGroupSortOrder = {
    expected = [
      { "C" = [ ]; }
      { "A" = [ ]; }
      { "B" = [ ]; }
    ];

    expr = shb.homepage.asServiceGroup {
      A = {
        sortOrder = 2;
        services = { };
      };
      B = {
        sortOrder = 3;
        services = { };
      };
      C = {
        sortOrder = 1;
        services = { };
      };
    };
  };

  testHomepageAsServiceServicesSortOrder = {
    expected = [
      {
        "Media" = [
          {
            "A" = {
              "href" = "https://example.com/a";
              "icon" = "sh-a";
              "siteMonitor" = null;
            };
          }
          {
            "C" = {
              "href" = "https://example.com/c";
              "icon" = "sh-c";
              "siteMonitor" = null;
            };
          }
          {
            "B" = {
              "href" = "https://example.com/b";
              "icon" = "sh-b";
              "siteMonitor" = null;
            };
          }
        ];
      }
    ];

    expr = shb.homepage.asServiceGroup {
      Media = {
        sortOrder = null;
        services = {
          A = {
            sortOrder = 1;
            dashboard.request = {
              externalUrl = "https://example.com/a";
              internalUrl = null;
            };
            apiKey = null;
          };
          B = {
            sortOrder = 3;
            dashboard.request = {
              externalUrl = "https://example.com/b";
              internalUrl = null;
            };
            apiKey = null;
          };
          C = {
            sortOrder = 2;
            dashboard.request = {
              externalUrl = "https://example.com/c";
              internalUrl = null;
            };
            apiKey = null;
          };
        };
      };
    };
  };

  testHomepageAllKeys = {
    expected = {
      "A_A" = "path_A";
      "A_B" = "path_B";
      "B_D" = "path_D";
    };

    expr = shb.homepage.allKeys {
      A = {
        sortOrder = 1;
        services = {
          A = {
            sortOrder = 1;
            dashboard.request = {
              externalUrl = "https://example.com/a";
              internalUrl = null;
            };
            apiKey.result.path = "path_A";
          };
          B = {
            sortOrder = 2;
            dashboard.request = {
              externalUrl = "https://example.com/b";
              internalUrl = null;
            };
            apiKey.result.path = "path_B";
          };
        };
      };
      B = {
        sortOrder = 2;
        services = {
          C = {
            sortOrder = 1;
            dashboard.request = {
              externalUrl = "https://example.com/a";
              internalUrl = null;
            };
            apiKey = null;
          };
          D = {
            sortOrder = 2;
            dashboard.request = {
              externalUrl = "https://example.com/b";
              internalUrl = null;
            };
            apiKey.result.path = "path_D";
          };
        };
      };
    };
  };
}
