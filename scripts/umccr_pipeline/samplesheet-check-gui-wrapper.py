from gooey import Gooey, GooeyParser
ss = __import__('samplesheet-check')


@Gooey()
def main():
    parser = GooeyParser(description="A Graphical User Interface for the sampleSheet check script")
    parser.add_argument('samplesheet',
                        metavar='samplesheet',
                        help='The Samplesheet to check',
                        widget='FileChooser')

    return parser.parse_args()


def show_error_modal(error_msg):
    """ Spawns a modal with error_msg"""
    # wx imported locally so as not to interfere with Gooey
    import wx
    app = wx.App()
    dlg = wx.MessageDialog(None, error_msg, 'Error', wx.ICON_ERROR)
    dlg.ShowModal()
    dlg.Destroy()


args = main()
print(f"Samplesheet: {args.samplesheet}")

try:
    ss.main(args.samplesheet, True)
except ValueError as ve:
    print(ve)
    show_error_modal(str(ve))
