# Cac_Spring26
## Flow Setup
Setting up the flow locally depends on the type of OS you are using.
### Windows 10+
1. Setup WSL and install Nix by following the documentation provided by LibreLane [here](https://librelane.readthedocs.io/en/latest/installation/nix_installation/installation_win.html).
2. Restart the Ubuntu terminal after installing Nix.
3. This repo already contains a static clone of LibreLane, so you don't need to clone it. 
3. Navigate to `librelane/` and run `nix-shell`. The first run should take a bit, but future runs will be faster.
4. Run `librelane --smoke-test` in the nix shell to test the installation. This takes ~1 minutes, and if all is well, it should say `Smoke test passed`.
5. In the future, to run the flow, simply run `nix-shell` inside the `librelane/` directory.