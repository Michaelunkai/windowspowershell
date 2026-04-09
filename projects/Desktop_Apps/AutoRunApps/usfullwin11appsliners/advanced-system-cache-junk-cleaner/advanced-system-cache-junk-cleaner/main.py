import argparse
from engine import CleanupEngine
from gui import launch_gui


def cli_scan():
    engine = CleanupEngine()
    report = engine.scan()

    print("\n==== Cleanup Scan Report ====\n")
    for section, data in report.items():
        if section == "TOTAL CLEANABLE":
            print(f"\nTOTAL CLEANABLE: {data}")
        else:
            print(f"\n{section}:")
            for p, s in data.items():
                print(f"  - {p} -> {s}")
    print("\n")


def cli_clean():
    engine = CleanupEngine()
    results = engine.cleanup_execute()

    print("\n==== Cleaned ====\n")
    for sec, value in results.items():
        print(f"{sec}: {value}")
    print("\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("--gui", action="store_true", help="Launch GUI")
    parser.add_argument("--scan", action="store_true", help="Scan system")
    parser.add_argument("--clean", action="store_true", help="Clean system")

    args = parser.parse_args()

    if args.gui:
        launch_gui()

    elif args.scan:
        cli_scan()

    elif args.clean:
        cli_clean()

    else:
        print("Usage:")
        print("  python main.py --gui")
        print("  python main.py --scan")
        print("  python main.py --clean")
