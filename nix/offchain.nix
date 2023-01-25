{ self, config, lib, flake-parts-lib, ... }:

let
  inherit (flake-parts-lib)
    mkSubmoduleOptions
    mkPerSystemOption;

  inherit (lib) types;
in
{
  options = {
    perSystem = mkPerSystemOption
      ({ config, self', inputs', pkgs, system, ... }:
        let
          shell = types.submodule {
            options = {
              extraCommandLineTools = lib.mkOption {
                type = types.listOf types.package;
                description = ''
                  List of extra packages to make available to the shell.

                  Added in: 2.1.0.
                '';
                default = [ ];
              };
              shellHook = lib.mkOption {
                type = types.lines;
                description = ''
                  Shell code to run when the shell is started.

                  Added in: 2.3.0.
                '';
                default = "";
              };
            };
          };

          # NOTE: probably a simple types.str would be enough here, but we want
          # to differentiate this kind of string from stringified paths, which
          # is what most of CTL's flake takes as input.
          purescriptModule =
            types.strMatching
              ''[[:upper:]][[:alnum:]]*(\.[[:upper:]][[:alnum:]]*)*'';

          bundle = types.submodule
            {
              options = {
                mainModule = lib.mkOption {
                  description = ''
                    The main Purescript module for the bundle (for instance, 'Main').

                    Added in: 2.1.0.
                  '';
                  type = purescriptModule;
                };

                entrypointJs = lib.mkOption {
                  description = ''
                    Stringified path to the webpack `entrypoint` file.

                    Added in: 2.1.0.
                  '';

                  # NOTE: ideally, this would be a types.path, but it's easier to
                  # conform to CTL's types.
                  type = types.str;
                  default = "index.js";
                };

                browserRuntime = lib.mkOption {
                  description = ''
                    Whether this bundle is being produced for a browser environment or
                    not.

                    Added in: 2.1.0.
                  '';
                  type = types.bool;
                  default = true;
                };

                webpackConfig = lib.mkOption {
                  description = ''
                    Stringified path to the Webpack config file to use.

                    Added in: 2.1.0.
                  '';
                  type = types.str;
                  default = "webpack.config.js";
                };

                bundledModuleName = lib.mkOption {
                  description = ''
                    The name of the file containing the bundled JS module that
                    `spago bundle-module` will produce.

                    Added in: 2.1.0.
                  '';
                  type = types.str;
                  default = "output.js";
                };

                enableCheck = lib.mkOption {
                  description = ''
                    Whether to add a flake check testing that the bundle builds
                    correctly.

                    Added in: 2.1.0.
                  '';
                  type = types.bool;
                  default = false;
                };

                includeBundledModule = lib.mkOption {
                  description = ''
                    Whether to include the spago bundle-module output in `dist` in the bundle.

                    Added in: 2.2.2.
                  '';
                  type = types.bool;
                  # This can be default true because it's basically free.
                  default = true;
                };
              };
            };

          testConfigs = types.submodule {
            options = {
              buildInputs = lib.mkOption {
                type = types.listOf types.package;
                description = ''
                  Additional packages passed through to the `buildInputs` of
                  the derivation.

                  Added in: 2.1.0.
                '';
                default = [ ];
              };

              testMain = lib.mkOption {
                description = ''
                  The name of the main Purescript module containing the test suite.

                  Added in: 2.1.0.
                '';
                type = purescriptModule;
              };
            };
          };

          runtime = types.submodule {
            options = {
              enableCtlServer = lib.mkOption {
                description = ''
                  Whether to enable or disable the CTL server (used to apply
                  arguments to scripts and evaluate UPLC). Enabling this will
                  also add the ctl-server overlay.

                  Added in: 2.1.0.
                '';
                type = types.bool;
                default = false;
              };

              extraConfig = lib.mkOption {
                description = ''
                  Additional config options to pass to the CTL runtime. See
                  `runtime.nix` in the CTL flake for a reference of the
                  available options.

                  By default, the runtime is set to use the `preview` network
                  and the same node version that CTL uses in its tests.

                  Added in: 2.1.0.
                '';
                type = types.attrsOf types.anything;
                default = { };
              };

              exposeConfig = lib.mkOption {
                description = ''
                  Whether to expose the runtime config as an attribute set in
                  `packages`. Config is not a package so you may want to set it
                  to false.

                  Added in: 2.3.0.
                '';
                type = types.bool;
                default = true;
              };
            };
          };

          project = types.submodule {
            options = {
              src = lib.mkOption {
                description = ''
                  Path to the project's source code, including its package.json
                  and package-lock.json files.

                  Added in: 2.1.0.
                '';
                type = types.path;
              };

              pkgs = lib.mkOption {
                description = ''
                  Package set to use. If specified, you must also manually apply
                  CTL overlays.
                '';
                default = null;
                type = types.nullOr (types.raw or types.unspecified);
              };

              ignoredWarningCodes = lib.mkOption {
                description = ''
                  Warnings from `purs` to silence during compilation.

                  Added in: 2.1.0.
                '';
                default = [ ];
                type = types.listOf types.str;
              };

              shell = lib.mkOption {
                description = ''
                  Options to configure the project's devShell.

                  Added in: 2.1.0.
                '';
                type = shell;
                default = { };
              };

              bundles = lib.mkOption {
                description = ''
                  A map of bundles to be produced for this project.

                  Added in: 2.1.0.
                '';
                type = types.attrsOf bundle;
                default = { };
              };

              plutip = lib.mkOption {
                description = ''
                  Options to configure the project's Plutip suite. If defined,
                  a flake check will be created which runs the tests. 

                  Added in: 2.1.0.
                '';
                type = types.nullOr testConfigs;
                default = null;
              };

              tests = lib.mkOption {
                description = ''
                  Options to configure the project's (non-Plutip) tests. If defined,
                  a flake check will be created which runs the tests.

                  Added in: 2.1.0.
                '';
                type = types.nullOr testConfigs;
                default = null;
              };

              runtime = lib.mkOption {
                description = ''
                  Options to configure CTL's runtime.

                  Added in: 2.1.0.
                '';
                type = runtime;
                default = { };
              };

              enableFormatCheck = lib.mkOption {
                description = ''
                  Whether to add a flake check verifying that the code
                  (including the flake.nix and any JS files in the project) has
                  been formatted.

                  Added in: 2.1.0.
                '';
                type = types.bool;
                default = false;
              };

              enableJsLintCheck = lib.mkOption {
                description = ''
                  Whether to add a check verifying that the JS files in the
                  project have been linted.

                  Added in: 2.1.0.
                '';
                type = types.bool;
                default = false;
              };

              nodejsPackage = lib.mkOption {
                description = ''
                  The nodejs package to use.

                  Added in: 2.1.1.
                '';
                type = types.package;
                default = pkgs.nodejs-14_x;
              };
            };
          };
        in
        {
          options.offchain = lib.mkOption {
            description = ''
              A CTL project declaration, with arbitrarily many bundles, a
              devShell and optional tests.

              In order to use this, your repository must provide the `cardano-transaction-lib` input.

              Added in: 2.1.0.
            '';
            type = types.attrsOf project;
            default = { };
          };
        });
  };
  config = {
    perSystem = { config, self', inputs', pkgs, lib, system, ... }:
      let
        liqwid-nix = self.inputs.liqwid-nix.inputs;

        ctl-overlays = assert (lib.assertMsg (self.inputs ? cardano-transaction-lib) ''
          [liqwid-nix]: liqwid-nix offchain module is being used. Please provide a 'cardano-transaction-lib' input.
        ''); self.inputs.cardano-transaction-lib.overlays;

        projectConfigs = config.offchain;
        utils = import ./utils.nix { inherit pkgs lib; };

        defaultCtlOverlays = with ctl-overlays; [
          purescript
          runtime
          spago
        ];

        includeCtlServer =
          lib.any
            (project: project.runtime.enableCtlServer)
            (lib.attrValues projectConfigs);

        additionalOverlays =
          if includeCtlServer
          then [ ctl-overlays.ctl-server ]
          else [ ];

        nixpkgs-ctl = assert (lib.assertMsg (self.inputs ? nixpkgs-ctl) ''
          [liqwid-nix] liqwid-nix offchain module is being used. Please provide a 'nixpkgs-ctl' input, as taken from 'cardano-transaction-lib'.
        ''); self.inputs.nixpkgs-ctl;

        # NOTE(Emily, 13 Jan 2023): This is currently semi-vendored from CTL. This shouldn't be necessary
        # once we are on a more recent version that supports including the spago result in the bundle.
        # 
        # The exact difference here is what is specified by 'includeBundledModule'. Additionally,
        # some work has been done to ensure this can work while being outside of the context of the
        # 'project' scope (by taking 'project' as an argument).
        #
        # This workaround will no longer be necessary as soon as the PR is merged and we are up to date:
        # https://github.com/Plutonomicon/cardano-transaction-lib/pull/1396
        #
        # Bundles a Purescript project using Webpack, typically for the browser
        bundlePursProject =
          {
            # Can be used to override the name given to the resulting derivation
            name
            # The Webpack `entrypoint`
          , entrypoint ? "index.js"
            # The main Purescript module
          , main ? "Main"
            # If this bundle is being produced for a browser environment or not
          , browserRuntime ? true
            # Path to the Webpack config to use
          , webpackConfig ? "webpack.config.js"
            # The name of the bundled JS module that `spago bundle-module` will produce
          , bundledModuleName ? "output.js"
            # Generated `node_modules` in the Nix store. Can be passed to have better
            # control over individual project components
          , nodeModules ? project.nodeModules
            # If the spago bundle-module output should be included in the derivation
          , includeBundledModule ? false
            # The project object
          , project
          , pkgs
          , ...
          }:
          pkgs.runCommand "${name}"
            {
              buildInputs = [
                project.nodejs
                nodeModules
                project.compiled
              ];
              nativeBuildInputs = [
                pkgs.easy-ps.purs-0_14_5
                pkgs.easy-ps.spago
              ];
            }
            ''
              export HOME="$TMP"
              export NODE_PATH="${nodeModules}/lib/node_modules"
              export PATH="${nodeModules}/bin:$PATH"
              ${pkgs.lib.optionalString browserRuntime "export BROWSER_RUNTIME=1"}
              cp -r ${project.compiled}/* .
              chmod -R +rwx .
              spago bundle-module --no-install --no-build -m "${main}" \
                --to ${bundledModuleName}
              mkdir ./dist
              ${pkgs.lib.optionalString includeBundledModule "cp ${bundledModuleName} ./dist"}
              webpack --mode=production -c ${webpackConfig} -o ./dist \
                --entry ./${entrypoint}
              mkdir $out
              mv dist $out
            '';

        # ----------------------------------------------------------------------

        makeProject = projectName: projectConfig:
          let
            pkgs = projectConfig.pkgs or (import nixpkgs-ctl {
              inherit system;
              overlays = defaultCtlOverlays ++ additionalOverlays;
            });

            nodejsPackage = projectConfig.nodejsPackage;

            defaultCommandLineTools = with pkgs; [
              dhall
              easy-ps.purs-tidy
              fd
              nixpkgs-fmt
              nodePackages.eslint
              nodePackages.npm
              nodePackages.prettier
              nodejsPackage
            ];

            commandLineTools =
              defaultCommandLineTools
              ++ projectConfig.shell.extraCommandLineTools;

            project =
              let
                pkgSet = pkgs.purescriptProject {
                  inherit (projectConfig) src;

                  inherit projectName pkgs;

                  nodejs = nodejsPackage;

                  packageJson = projectConfig.src + "/package.json";
                  packageLock = projectConfig.src + "/package-lock.json";

                  censorCodes = projectConfig.ignoredWarningCodes;

                  shell = {
                    withRuntime = true;
                    packageLockOnly = true;
                    packages = commandLineTools;
                    shellHook = ''
                      liqwid(){ c=$1; shift; nix run .#$c -- $@; }
                    ''
                    + projectConfig.shell.shellHook;
                  };
                };
              in
              pkgSet;

            bundles = (lib.mapAttrs
              (name: bundle: bundlePursProject {
                inherit (bundle)
                  bundledModuleName
                  webpackConfig
                  includeBundledModule
                  browserRuntime;
                inherit name project pkgs;

                main = bundle.mainModule;
                entrypoint = bundle.entrypointJs;
              })
              projectConfig.bundles);

            bundleChecks =
              lib.mapAttrs'
                (bundleName: _: {
                  name = "build:${bundleName}";
                  value = bundles.${bundleName};
                })
                (lib.filterAttrs
                  (_: projectBundle: projectBundle.enableCheck)
                  projectConfig.bundles);


            purescriptCheck = lib.ifEnable
              (projectConfig ? tests)
              {
                tests =
                  (project.runPursTest {
                    inherit (projectConfig.tests)
                      sources
                      buildInputs
                      testMain;
                  });
              };

            plutipCheck =
              lib.ifEnable
                (projectConfig ? plutip)
                {
                  plutip-tests =
                    (project.runPlutipTest {
                      inherit (projectConfig.plutip)
                        sources
                        buildInputs
                        testMain;
                    });
                };

            formattingCheck =
              lib.ifEnable
                projectConfig.enableFormatCheck
                {
                  formatting-check =
                    (pkgs.runCommand "formatting-check"
                      {
                        nativeBuildInputs = commandLineTools ++ [ project.nodeModules ];
                      }
                      ''
                        cd ${self}
                        purs-tidy check $(fd -epurs)
                        nixpkgs-fmt --check $(fd -enix --exclude='spago*')
                        prettier -c $(fd -ejs)
                        touch $out
                      '');
                };

            jsLintCheck =
              lib.ifEnable
                projectConfig.enableJsLintCheck
                {
                  js-lint-check = (pkgs.runCommand "js-lint-check"
                    {
                      nativeBuildInputs = commandLineTools ++ [ project.nodeModules ];
                    }
                    ''
                      cd ${self}
                      eslint $(fd -ejs)
                      touch $out
                    '');
                };

            checks = lib.fold lib.mergeAttrs { } [
              bundleChecks
              ({
                bundle-checks =
                  utils.combineChecks "bundle-checks" bundleChecks;
              })
              purescriptCheck
              plutipCheck
              formattingCheck
              jsLintCheck
            ];

            ctlRuntimeConfig = projectConfig.runtime.extraConfig // {
              ctlServer.enable = projectConfig.runtime.enableCtlServer;
            };
          in
          {
            packages = bundles //
              (if projectConfig.runtime.exposeConfig
              then { ctl-runtime = pkgs.buildCtlRuntime ctlRuntimeConfig { }; }
              else { });

            run.nixFormat =
              {
                dependencies = with pkgs; [ fd nixpkgs-fmt ];
                script = '' fd -enix --exclude='spago*' -x nixpkgs-fmt {} '';
                groups = [ "format" "precommit" ];
                help = ''
                  echo "  Formats nix files using nixpkgs-fmt."
                '';
              };

            run.pursFormat =
              {
                dependencies = with pkgs; [ fd easy-ps.purs-tidy ];
                script = '' fd -epurs -X purs-tidy format-in-place {} '';
                groups = [ "format" "precommit" ];
                help = ''
                  echo "  Formats PureScript files using purs-tidy."
                '';
              };

            run.jsFormat =
              {
                dependencies = with pkgs; [ fd nodePackages.prettier ];
                script = '' fd -ejs -ets -X prettier -w {} '';
                groups = [ "format" "precommit" ];
                help = ''
                  echo "  Formats Javascript/TypeScript files using prettier."
                '';
              };

            run.spago2nix =
              {
                dependencies = [ pkgs.easy-ps.spago2nix ];
                script = '' spago2nix generate  '';
                groups = [ "updateCtl" ];
                help = ''
                  echo "  Regenerates the spago.nix file."
                '';
              };

            inherit checks;
            check = utils.combineChecks "combined-checks" checks;

            apps = {
              ctl-runtime = pkgs.launchCtlRuntime ctlRuntimeConfig;
              docs = project.launchSearchablePursDocs { };
            };

            devShell = project.devShell;
          };

        # ----------------------------------------------------------------------

        projects = lib.mapAttrs makeProject projectConfigs;

        projectChecks =
          lib.filterAttrs (_: check: check != { })
            (utils.flat2With utils.buildPrefix
              (lib.mapAttrs
                (_: project: project.checks // { all = project.check; })
                projects));

        projectScripts =
          utils.flat2With utils.buildPrefix
            (lib.mapAttrs
              (_: project: project.run)
              projects);

        moduleUsed = projectChecks != { };
      in
      {
        packages =
          utils.flat2With utils.buildPrefix
            (lib.mapAttrs
              (_: project: project.packages)
              projects);

        run = projectScripts;

        apps =
          utils.flat2With utils.buildPrefix
            (lib.mapAttrs
              (_: project: project.apps)
              projects);

        checks = projectChecks // (lib.ifEnable moduleUsed {
          all_offchain = utils.combineChecks "all_offchain" projectChecks;
        });

        devShells = lib.mapAttrs (_: project: project.devShell) projects;
      };
  };
}
