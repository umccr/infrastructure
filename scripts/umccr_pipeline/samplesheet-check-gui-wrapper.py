from gooey import Gooey, GooeyParser
ss = __import__('samplesheet-check-copy')


@Gooey()
def main():
    parser = GooeyParser(description="A Graphical User Interface for the sampleSheet check script")
    parser.add_argument('samplesheet',
                        metavar='samplesheet',
                        help='The Samplesheet to check',
                        widget='FileChooser')

    return parser.parse_args()


args = main()
print(f"Samplesheet: {args.samplesheet}")

try:
    ss.main(args.samplesheet, True)
except ValueError as ve:
    message = ve
