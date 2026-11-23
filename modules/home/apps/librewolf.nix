{ pkgs, config, lib, vicinae, palette, ... }:

let
  vicinaePkg = vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;
  c = palette.colors;

  userChromeContent = ''
    :root {
      --toolbar-bgcolor: ${c.mantle} !important;
      --toolbar-color: ${c.text} !important;
      --lwt-accent-color: ${c.base} !important;
      --lwt-text-color: ${c.text} !important;
      --toolbox-bgcolor: ${c.base} !important;
      --toolbox-bgcolor-inactive: ${c.base} !important;
      --tabs-navbar-separator-color: ${c.borderSubtle} !important;
      --arrowpanel-background: ${c.base} !important;
      --arrowpanel-color: ${c.text} !important;
      --arrowpanel-border-color: ${c.border} !important;
      --panel-background: ${c.base} !important;
      --panel-color: ${c.text} !important;
      --panel-border-color: ${c.border} !important;
      --button-hover-bgcolor: ${c.surface0} !important;
      --button-active-bgcolor: ${c.surface1} !important;
      --autocomplete-popup-background: ${c.base} !important;
      --autocomplete-popup-color: ${c.text} !important;
      --autocomplete-popup-highlight-background: ${c.surface1} !important;
      --chrome-content-separator-color: transparent !important;
      --focus-outline-color: ${c.accent} !important;
      --toolbar-field-focus-border-color: ${c.accent} !important;
      --toolbar-field-border-color: ${c.border} !important;
      --accent-color: ${c.accent} !important;
      --toolbar-field-background-color: ${c.base} !important;
      --toolbar-field-focus-background-color: ${c.base} !important;
      --toolbar-field-color: ${c.text} !important;
      --toolbar-field-focus-color: #ffffff !important;
      --lwt-toolbar-field-background-color: ${c.base} !important;
      --lwt-toolbar-field-focus: ${c.base} !important;
      --lwt-toolbar-field-color: ${c.text} !important;
      --lwt-toolbar-field-focus-color: #ffffff !important;
      --urlbar-box-bgcolor: ${c.base} !important;
      --urlbar-box-hover-bgcolor: ${c.surface0} !important;
      --urlbar-box-focus-bgcolor: ${c.base} !important;
      --urlbar-popup-url-color: ${c.accent} !important;
      --urlbar-popup-action-color: ${c.accent} !important;
      --tab-selected-bgcolor: ${c.surface0} !important;
      --tab-hover-background-color: ${c.surface0} !important;
      --sidebar-background-color: ${c.base} !important;
      --sidebar-text-color: ${c.text} !important;
      --sidebar-border-color: ${c.borderSubtle} !important;
    }

    ::selection, *::-moz-selection {
      background-color: ${c.accent} !important;
      color: #ffffff !important;
    }

    .titlebar-buttonbox-container,
    .titlebar-spacer,
    #back-button,
    #forward-button,
    #stop-reload-button,
    #reload-button,
    #stop-button,
    #home-button,
    #downloads-button,
    #library-button,
    #fxa-toolbar-menu-button,
    #sidebar-button,
    #firefox-view-button,
    #PanelUI-button,
    #new-tab-button,
    #tabs-newtab-button,
    #alltabs-button,
    #private-browsing-indicator-with-label,
    .tab-close-button,
    #star-button-box,
    #reader-mode-button,
    #picture-in-picture-button,
    #translations-button,
    #pageActionButton,
    #tracking-protection-icon-container,
    toolbarspring {
      display: none !important;
    }

    #main-window,
    #browser,
    #tabbrowser-tabpanels,
    #TabsToolbar,
    #titlebar {
      background-color: ${c.base} !important;
    }

    #navigator-toolbox {
      background-color: ${c.base} !important;
      border-bottom: 1px solid ${c.borderSubtle} !important;
    }

    #nav-bar {
      background-color: ${c.mantle} !important;
      box-shadow: none !important;
      padding: 2px 6px !important;
    }

    #urlbar,
    #urlbar * {
      --toolbar-field-background-color: ${c.base} !important;
      --toolbar-field-focus-background-color: ${c.base} !important;
      --lwt-toolbar-field-background-color: ${c.base} !important;
      --lwt-toolbar-field-focus: ${c.base} !important;
      --urlbar-box-bgcolor: ${c.base} !important;
    }

    #urlbar,
    #urlbar-background,
    .urlbar-background,
    #urlbar-input-container,
    .urlbar-input-container,
    .urlbar-input,
    .urlbar-input-box,
    #urlbar-input,
    #searchbar,
    .searchbar-textbox,
    input.textbox-input {
      appearance: none !important;
      -moz-appearance: none !important;
      background-color: ${c.base} !important;
      background: ${c.base} !important;
      border-color: ${c.border} !important;
      color: ${c.text} !important;
    }

    #urlbar-background,
    .urlbar-background,
    #searchbar,
    .searchbar-textbox {
      border: 1px solid ${c.border} !important;
      border-radius: 8px !important;
      box-shadow: none !important;
    }

    #urlbar[focused] > #urlbar-background,
    #urlbar[focused] > .urlbar-background,
    #urlbar[focused="true"] > #urlbar-background,
    #urlbar[focused="true"] > .urlbar-background,
    #searchbar:focus-within {
      border-color: ${c.accent} !important;
      box-shadow: 0 0 0 1px ${c.accent} !important;
    }

    #urlbar-input, .searchbar-textbox {
      font-family: "${palette.font.mono}", monospace !important;
      font-size: 13px !important;
    }

    #identity-box {
      background-color: transparent !important;
      color: ${c.subtext0} !important;
    }

    #identity-box:hover {
      background-color: ${c.surface0} !important;
      border-radius: 6px !important;
    }

    #urlbar-search-mode-indicator {
      background-color: ${c.accent} !important;
      color: #ffffff !important;
      border-radius: 6px !important;
    }

    #urlbar[open] > #urlbar-background,
    #urlbar[open] > .urlbar-background,
    #urlbar[breakout][breakout-extend] > #urlbar-background,
    #urlbar[breakout][breakout-extend] > .urlbar-background,
    #urlbar[breakout][breakout-extend] > #urlbar-input-container,
    #urlbar-results,
    #urlbarView-results,
    .urlbarView,
    .urlbarView-body-outer,
    .urlbarView-body-inner,
    .urlbarView-results,
    .search-one-offs,
    .search-panel-one-offs-header {
      appearance: none !important;
      -moz-appearance: none !important;
      background-color: ${c.base} !important;
      background: ${c.base} !important;
      border-color: ${c.accent} !important;
      color: ${c.text} !important;
    }

    .urlbarView-row,
    .urlbarView-row-inner {
      appearance: none !important;
      -moz-appearance: none !important;
      background-color: ${c.base} !important;
      background: ${c.base} !important;
      border-radius: 6px !important;
    }

    .urlbarView-row:hover,
    .urlbarView-row:hover .urlbarView-row-inner {
      background-color: ${c.surface0} !important;
      background: ${c.surface0} !important;
    }

    .urlbarView-row[selected],
    .urlbarView-row[selected] .urlbarView-row-inner {
      background-color: ${c.surface1} !important;
      background: ${c.surface1} !important;
    }

    .urlbarView-row[selected] .urlbarView-title {
      color: #ffffff !important;
    }

    .urlbarView-title strong,
    .urlbarView-url strong {
      color: ${c.accent} !important;
      font-weight: 600 !important;
    }

    .urlbarView-row .urlbarView-action,
    .urlbarView-type-icon {
      color: ${c.accent} !important;
      fill: ${c.accent} !important;
    }

    .search-one-offs .searchbar-engine-one-off-item:hover {
      background-color: ${c.surface0} !important;
    }

    .search-one-offs .searchbar-engine-one-off-item[selected] {
      background-color: ${c.accent} !important;
    }

    tab {
      font-family: "${palette.font.mono}", monospace !important;
      font-size: 12px !important;
    }

    .tab-background {
      border-radius: 8px !important;
      margin-block: 3px !important;
      box-shadow: none !important;
    }

    .tabbrowser-tab[selected="true"] .tab-background {
      background-color: ${c.surface0} !important;
      border: 1px solid ${c.surface2} !important;
      border-bottom: 2px solid ${c.accent} !important;
      box-shadow: none !important;
    }

    .tabbrowser-tab:hover:not([selected="true"]) .tab-background {
      background-color: ${c.surface0} !important;
    }

    .tab-label {
      color: ${c.subtext0} !important;
    }

    .tabbrowser-tab[selected="true"] .tab-label {
      color: #ffffff !important;
      font-weight: 500 !important;
    }

    #sidebar-box,
    #sidebar-header,
    #sidebar-main,
    sidebar-main {
      background-color: ${c.base} !important;
      color: ${c.text} !important;
      border-color: ${c.borderSubtle} !important;
    }

    menupopup,
    panel,
    .panel-subview-body,
    panelview {
      --arrowpanel-background: ${c.base} !important;
      --arrowpanel-color: ${c.text} !important;
      --arrowpanel-border-color: ${c.border} !important;
      --panel-background: ${c.base} !important;
      --panel-color: ${c.text} !important;
      --panel-border-color: ${c.border} !important;
      background-color: ${c.base} !important;
      color: ${c.text} !important;
      border-color: ${c.border} !important;
    }

    menuitem:hover,
    menu:hover,
    .subviewbutton:hover {
      background-color: ${c.surface0} !important;
    }

    #PersonalToolbar {
      background-color: ${c.mantle} !important;
      color: ${c.text} !important;
      border-bottom: 1px solid ${c.borderSubtle} !important;
    }

    #statuspanel-label {
      background-color: ${c.mantle} !important;
      color: ${c.text} !important;
      border: 1px solid ${c.border} !important;
      border-radius: 6px !important;
    }

    findbar {
      background-color: ${c.mantle} !important;
      border-top: 1px solid #2c2d35 !important;
      color: ${c.text} !important;
      border-radius: 8px 8px 0 0 !important;
    }

    findbar textbox:focus {
      outline: 1px solid ${c.accent} !important;
    }
  '';

  userContentContent = ''
    @-moz-document url("about:home"), url("about:newtab"), url("about:blank"), url("about:privatebrowsing") {
      html, html.private, body, #root, .activity-stream, .outer-wrapper, .private-browsing-container {
        background-color: ${c.base} !important;
        background: ${c.base} !important;
        color: ${c.text} !important;
      }
      .search-inner-wrapper,
      .search-handoff-button,
      .search-wrapper .search-handoff-button,
      input[type="search"],
      .search-wrapper input {
        appearance: none !important;
        -moz-appearance: none !important;
        background-color: ${c.base} !important;
        background: ${c.base} !important;
        border: 1px solid ${c.border} !important;
        color: ${c.text} !important;
        border-radius: 8px !important;
      }
      .search-inner-wrapper:focus-within,
      .search-handoff-button:focus,
      .search-wrapper .search-handoff-button:focus,
      input[type="search"]:focus,
      .search-wrapper input:focus {
        border-color: ${c.accent} !important;
        box-shadow: 0 0 0 1px ${c.accent} !important;
      }
    }
  '';

  userChromeFile = pkgs.writeText "userChrome.css" userChromeContent;
  userContentFile = pkgs.writeText "userContent.css" userContentContent;
in
{
  programs.librewolf = {
    enable = true;
    nativeMessagingHosts = [ vicinaePkg ];

    policies = {
      DisableAppUpdate = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableTelemetry = true;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
      };
      ExtensionSettings = {
        "*".installation_mode = "allowed";

        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };
        "vimium-c@gdh1995.cn" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-c/latest.xpi";
        };
        "firefox@tampermonkey.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/tampermonkey/latest.xpi";
        };
        "leechblockng@proginosko.com" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/leechblock-ng/latest.xpi";
        };
        "firefox@vicinae.com" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/vicinae/latest.xpi";
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
          private_browsing = true;
        };
      };
    };

    profiles.default = {
      id = 0;
      isDefault = true;

      settings = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "browser.tabs.drawInTitlebar" = true;
        "browser.tabs.inTitlebar" = 1;
        "browser.uidensity" = 1;
        "browser.compactmode.show" = true;
        "browser.toolbars.bookmarks.visibility" = "never";
        "browser.tabs.tabmanager.enabled" = false;
        "sidebar.revamp" = false;
        "browser.theme.toolbar-theme" = 0;
        "browser.theme.content-theme" = 0;
        "layout.css.prefers-color-scheme.content-override" = 0;
        "ui.systemUsesDarkTheme" = 1;
        "widget.non-native-theme.gtk.accent-color" = c.accent;
        "widget.gtk.rounded-bottom-corners.enabled" = false;
        "widget.wayland.opaque-region.enabled" = true;
        "extensions.enabledScopes" = 15;
        "extensions.autoDisableScopes" = 0;
        "extensions.installDistroAddons" = true;
        "extensions.vimium-c.excludedUrls" = "";
        "extensions.tampermonkey.scriptSync" = true;
      };

      userChrome = userChromeContent;
      userContent = userContentContent;

      extraConfig = ''
        user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
        user_pref("widget.non-native-theme.gtk.accent-color", "${c.accent}");
        user_pref("widget.gtk.rounded-bottom-corners.enabled", false);
        user_pref("widget.wayland.opaque-region.enabled", true);
        user_pref("browser.theme.toolbar-theme", 0);
        user_pref("browser.theme.content-theme", 0);
        user_pref("layout.css.prefers-color-scheme.content-override", 0);
        user_pref("ui.systemUsesDarkTheme", 1);
        user_pref("browser.uidensity", 1);
        user_pref("browser.toolbars.bookmarks.visibility", "never");
        user_pref("browser.tabs.tabmanager.enabled", false);
        user_pref("sidebar.revamp", false);
        user_pref("extensions.enabledScopes", 15);
        user_pref("extensions.autoDisableScopes", 0);
        user_pref("extensions.installDistroAddons", true);
      '';
    };
  };

  home.activation.librewolfCustomCss = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for dir in ~/.librewolf/*; do
      if [ -d "$dir" ] && [ ! -L "$dir/chrome/userChrome.css" ] && ([ -f "$dir/prefs.js" ] || [[ "$dir" == *default* ]]); then
        mkdir -p "$dir/chrome"
        cp -f ${userChromeFile} "$dir/chrome/userChrome.css"
        cp -f ${userContentFile} "$dir/chrome/userContent.css"
      fi
    done
  '';
}
