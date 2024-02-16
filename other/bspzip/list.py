import sys
import pathlib

if __name__ == "__main__":
    if (len(sys.argv) < 1):
        print("Not enough arguments")
        exit(1)

    output_file = sys.argv[1]
    zip_folder = sys.argv[2]

    f = open(output_file, "w")

    ZipDirectory = pathlib.Path(zip_folder)
    paths = ZipDirectory.rglob("*")
    firstline = True

    for path in list(paths):
        if path.is_file():
            if not firstline:
                f.write("\n")
            f.write(str(path.relative_to(zip_folder)).replace("\\", "/"))
            f.write("\n")
            f.write(str(path.resolve()))
            firstline = False

    print("all done")
    f.close()
