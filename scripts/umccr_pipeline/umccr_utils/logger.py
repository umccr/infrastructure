#!/usr/bin/env python3

import logging
from logging.handlers import RotatingFileHandler


def set_logger():
    """
    Initialise a logger
    :return:
    """
    new_logger = logging.getLogger(__name__)
    new_logger.setLevel(logging.DEBUG)

    # create a logging format
    formatter = logging.Formatter('%(asctime)s - %(module)s - %(name)s - %(levelname)s : %(lineno)d - %(message)s')

    # create a file handler
    file_handler = RotatingFileHandler(filename=LOG_FILE_NAME, maxBytes=100000000, backupCount=5)
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)

    # create a console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.WARNING)
    console_handler.setFormatter(formatter)

    # add the handlers to the logger
    new_logger.addHandler(file_handler)
    new_logger.addHandler(console_handler)

    return new_logger


def get_logger():
    """
    Return logger object
    :return:
    """

    return logging.getLogger()
