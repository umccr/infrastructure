#!/usr/bin/env python3

import logging
from logging.handlers import RotatingFileHandler
from globals import LOG_FILE_PREFIX, LOGGER_STYLE


def set_basic_logger():
    """
    Set the basic logger before we then take in the --deploy-env values to see where we write to
    :return:
    """
    # Get a basic logger
    logger = logging.getLogger(__name__)

    # Get a stderr handler
    console = logging.StreamHandler()

    # Set level
    console.setLevel(logging.DEBUG)

    # Set format
    formatter = logging.Formatter(LOGGER_STYLE)
    console.setFormatter(formatter)

    return logger


def set_logger(script_dir, script, deploy_env):
    """
    Initialise a logger
    :return:
    """
    new_logger = logging.getLogger(__name__)
    new_logger.setLevel(logging.DEBUG)

    # create a logging format
    formatter = logging.Formatter(LOGGER_STYLE)

    # create a file handler
    file_handler = RotatingFileHandler(filename=script_dir / script + LOG_FILE_PREFIX[deploy_env],
                                       maxBytes=100000000, backupCount=5)
    # Set Level
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
