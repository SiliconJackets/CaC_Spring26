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


### MacOS
Official Guide: https://librelane.readthedocs.io/en/stable/index.html
1. Install Nix using the following command 
```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --prefer-upstream-nix --no-confirm --extra-conf "
    extra-substituters = https://nix-cache.fossi-foundation.org
    extra-trusted-public-keys = nix-cache.fossi-foundation.org:3+K59iFwXqKsL7BNu6Guy0v+uTlwsxYQxjspXzqLYQs=
"
```
2. Clone flow-steps repo into local directory.
```bash
git clone --branch flow-setup --single-branch https://github.gatech.edu/SiliconJackets/Cac_Spring26.git
```
   
4. Create module folder under librelane/design
5. Place RTL designs (verilog files + config.json file) into librelane/design/module_name
6. Enter below command to enter nix-shell
```bash
nix-shell --pure ~/librelane/shell.nix
```
5. To run Librelane
```bash
librelane ~/design/module_name/config.json
```
