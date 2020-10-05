import logging
from gooey import Gooey, GooeyParser
ss = __import__('samplesheet-check')


@Gooey()
def main():
    parser = GooeyParser(description="A Graphical User Interface for the sampleSheet check script")
    parser.add_argument('samplesheet',
                        metavar='samplesheet',
                        help='The Samplesheet to check',
                        widget='FileChooser',
                        gooey_options=dict(wildcard="Sample Sheets (*.csv);*.csv"))
    parser.add_argument("--dev-mode",
                        metavar="Developer Mode",
                        default=False,
                        action="store_true",
                        help="Use only for development purposes",
                        widget="CheckBox")

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
# Set check_only attribute to true
setattr(args, "check_only", True)
# Set log-level
if getattr(args, "dev_mode", True):
    setattr(args, "log_level", logging.DEBUG)
    setattr(args, "deploy_env", "dev")
else:
    setattr(args, "log_level", logging.INFO)
    setattr(args, "deploy_env", "prod")


try:
    ss.main(args)
except ValueError as ve:
    print(ve)
    show_error_modal(str(ve))
