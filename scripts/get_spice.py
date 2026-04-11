import os
import glob
import argparse
import librelane
from librelane.flows import Flow

def main():
    parser = argparse.ArgumentParser(description="Run LibreLane flow and return the extracted SPICE file path.")
    
    parser.add_argument(
        "design_name", 
        type=str, 
        help="The name of the design to process (e.g., nand_dcdl, inv_dcdl)"
    )
    
    parser.add_argument(
        "--base-dir", 
        type=str, 
        default="/content/CAC_2026/librelane/design", 
        help="Path to the base design directory"
    )

    args = parser.parse_args()
    design_name = args.design_name
    base_design_dir = args.base_dir

    Classic = Flow.factory.get("Classic")
    librelane.logging.set_log_level("CRITICAL")

    design_dir = os.path.join(base_design_dir, design_name)
    config_path = os.path.join(design_dir, "config.json")

    if not os.path.exists(config_path):
        print(f"Error: Could not find config.json at {config_path}")
        return

    print(f"-> Starting flow for '{design_name}'...")

    try:
        flow = Classic(config_path)
        flow.start()
    except Exception as e:
        print(f"Error: Flow failed for {design_name}. Details: {e}")
        return

    run_dir = flow.run_dir
    spice_search_path = os.path.join(run_dir, "final", "spice", "*.spice")
    spice_files = glob.glob(spice_search_path)

    if spice_files:
        print("\nExtracted SPICE file located at:")
        print(spice_files[0])
    else:
        print(f"\nCouldn't locate the final SPICE file.")
        print(f"Check the logs in {run_dir} to see if Magic.SpiceExtraction failed.")

if __name__ == "__main__":
    main()