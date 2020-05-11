import logging

handler = logging.StreamHandler()
formatter = logging.Formatter('%(asctime)s %(name)-12s %(levelname)-8s %(message)s')
handler.setFormatter(formatter)
_logger = logging.getLogger()
_logger.addHandler(handler)
_logger.setLevel(logging.DEBUG)
