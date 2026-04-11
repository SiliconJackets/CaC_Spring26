import os
import glob
import argparse
import shutil
import librelane
from librelane.flows import Flow
from pathlib import Path


def run_flow(design_name, base_dir):
    """
    Runs the flow and places the SPICE netlist in spice/netlists/
    """
    Classic = Flow.factory.get("Classic")
    librelane.logging.set_log_level("CRITICAL")

    DESIGN_DIR = Path(base_dir) / "librelane" / "design" / f"{design_name}"
    CONFIG_PATH = DESIGN_DIR / "config.json"

    if not os.path.exists(CONFIG_PATH):
        print(f"Error: Could not find config.json at {CONFIG_PATH}")
        exit(1)

    print(f"-> Starting flow for '{design_name}'...")

    print(CONFIG_PATH)
    try:
        flow = Classic(str(CONFIG_PATH))
        flow.start()
    except Exception as e:
        print(f"Error: Flow failed for {design_name}. Details: {e}")
        exit(1)

    run_dir = flow.run_dir
    spice_search_path = os.path.join(run_dir, "final", "spice", "*.spice")
    spice_files = glob.glob(spice_search_path)

    if spice_files:
        print("\nExtracted SPICE file located at:")
        print(f"{spice_files[0]}\n")
    else:
        print(f"\nCouldn't locate the final SPICE file.")
        print(f"Check the logs in {run_dir} to see if Magic.SpiceExtraction failed.\n")
        exit(1)

    SPICE_DIR = Path(base_dir) / "spice"
    NETLISTS_DIR = SPICE_DIR / "netlists"
    NETLIST_DEST_PATH = NETLISTS_DIR / f"{design_name}.spice"

    print(f"Copying SPICE file to: {NETLIST_DEST_PATH}\n")
    try:
        os.makedirs(NETLIST_DEST_PATH.parent, exist_ok=True)
        shutil.copy2(spice_files[0], NETLIST_DEST_PATH)
    except Exception as e:
        print(f"Error: Failed to copy {spice_files[0]} to {NETLIST_DEST_PATH}. Details: {e}\n")

    print("Flow complete!\n")


def main():
    parser = argparse.ArgumentParser(
        description="Run LibreLane flow and return the extracted SPICE file path."
    )

    parser.add_argument(
        "design_name",
        type=str,
        help="The name of the design to process (e.g., nand_dcdl, inv_dcdl)",
    )

    parser.add_argument(
        "--base-dir",
        type=str,
        default="/content/CAC_2026",
        help="Path to the base design directory",
    )

    args = parser.parse_args()
    design_name = args.design_name
    base_dir = args.base_dir

    run_flow(design_name=design_name, base_dir=base_dir)


if __name__ == "__main__":
    main()
