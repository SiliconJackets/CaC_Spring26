import math
import argparse


def analyze_config(clk_period_ns, ctrl_bits=None, delay_ps=None):
    clk_ps = clk_period_ns * 1000

    print("====================================")
    print(f"Clock period: {clk_period_ns} ns ({clk_ps} ps)")
    print("====================================")

    if ctrl_bits is not None:
        stages = 2 ** ctrl_bits

        min_delay_ps = math.ceil(clk_ps / stages)
        recommended_delay_ps = math.ceil(clk_ps / (stages / 2))
        max_reasonable_delay_ps = clk_ps // 2

        print(f"CTRL_BITS = {ctrl_bits}")
        print(f"Stages    = {stages}")
        print("")
        print("Valid DELAY_PS range:")
        print(f"  MIN (can lock)      : {min_delay_ps} ps")
        print(f"  RECOMMENDED         : {recommended_delay_ps} ps")
        print(f"  MAX (reasonable)    : {max_reasonable_delay_ps} ps")

    if delay_ps is not None:
        print("")
        print(f"DELAY_PS = {delay_ps}")

        if ctrl_bits is not None:
            stages = 2 ** ctrl_bits
            max_delay = stages * delay_ps

            print(f"Max delay = {max_delay} ps ({max_delay/1000:.3f} ns)")

            if max_delay < clk_ps:
                print("ERROR: Cannot lock (delay range too small)")
            elif max_delay < 1.2 * clk_ps:
                print("WARNING: Barely enough range")
            else:
                print("OK: Sufficient range")

        if delay_ps > clk_ps:
            print("ERROR: Delay step larger than clock period")

        if delay_ps > clk_ps / 5:
            print("WARNING: Resolution too coarse")

        if delay_ps < 5:
            print("WARNING: Unrealistically small (simulation heavy)")

    print("====================================")


def suggest_configs(clk_period_ns):
    clk_ps = clk_period_ns * 1000

    print("====================================")
    print(f"Suggestions for CLK = {clk_period_ns} ns")
    print("====================================")

    for ctrl_bits in range(4, 9):
        stages = 2 ** ctrl_bits
        delay_ps = int(clk_ps / stages)

        print(f"CTRL_BITS={ctrl_bits:2d} → DELAY_PS≈{delay_ps:4d} ps "
              f"(range={stages*delay_ps/1000:.2f} ns)")

    print("====================================")


# 🔥 NEW: smart ctrl_bits suggestion
def recommend_ctrl_bits(clk_period_ns):
    clk_ps = clk_period_ns * 1000

    print("====================================")
    print(f"Recommended CTRL_BITS for CLK = {clk_period_ns} ns")
    print("====================================")

    candidates = []

    for ctrl_bits in range(3, 10):
        stages = 2 ** ctrl_bits
        delay_ps = clk_ps / stages

        # scoring heuristic
        score = 0

        # prefer delay step between 20–200 ps
        if 20 <= delay_ps <= 200:
            score += 2

        # prefer total delay ~1–2× clock
        total_delay = stages * delay_ps
        if clk_ps <= total_delay <= 2 * clk_ps:
            score += 2

        # prefer moderate size (not too big)
        if 32 <= stages <= 128:
            score += 2

        candidates.append((score, ctrl_bits, int(delay_ps), stages))

    # sort best first
    candidates.sort(reverse=True)

    for score, ctrl_bits, delay_ps, stages in candidates:
        print(f"CTRL_BITS={ctrl_bits:2d} | stages={stages:3d} | "
              f"DELAY_PS≈{delay_ps:4d} ps | score={score}")

    print("====================================")


def main():
    parser = argparse.ArgumentParser(description="DLL Configuration Analyzer")

    parser.add_argument("--clk", type=float, required=True,
                        help="Clock period in ns")

    parser.add_argument("--ctrl", type=int,
                        help="Control bits")

    parser.add_argument("--delay", type=int,
                        help="Delay per stage in ps")

    parser.add_argument("--suggest", action="store_true",
                        help="Suggest configs")

    parser.add_argument("--recommend", action="store_true",
                        help="Recommend best CTRL_BITS")

    args = parser.parse_args()

    if args.recommend:
        recommend_ctrl_bits(args.clk)
    elif args.suggest:
        suggest_configs(args.clk)
    else:
        analyze_config(
            clk_period_ns=args.clk,
            ctrl_bits=args.ctrl,
            delay_ps=args.delay
        )


if __name__ == "__main__":
    main()