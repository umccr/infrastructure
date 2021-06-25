import os
import json
from eb_util import send_event_to_bus, EventType, EventSource

event_bus_name = os.environ.get("EVENT_BUS_NAME")


def is_bssh_runs_event(event) -> bool:
    return True


def is_bssh_runs_complete_event(event) -> bool:
    return True


def is_wes_event(event) -> bool:
    return True


def is_wes_dragen_wgs_qc_event(event):
    pass


def is_wes_dragen_wgs_somatic_event(event):
    pass


def is_wes_dragen_wgs_germline_event(event):
    pass


def handler(event, context):
    # Log the received event in CloudWatch
    print("Handling orchestrator event.")
    print(f"Received event: {json.dumps(event)}")

    if is_bssh_runs_event(event):
        if is_bssh_runs_complete_event(event):
            data = {
                "seq_run_name": "foobar",
                "gds_path": "gds://seq-volume/Runs/foobar"
            }
            send_event_to_bus(bus_name=event_bus_name,
                              event_source=EventSource.ORCHESTRATOR,
                              event_type=EventType.BCL_CONVERT,
                              event_payload=data)
        else:
            # Do something else
            pass
    elif is_wes_event(event):
        if is_wes_dragen_wgs_qc_event(event):
            pass
        elif is_wes_dragen_wgs_germline_event(event):
            pass
        elif is_wes_dragen_wgs_somatic_event(event):
            pass
        else:
            pass
    else:
        pass
