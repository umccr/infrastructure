# coding: utf-8
import pprint
import re  # noqa: F401

import six
from enum import Enum

class Event(object):


    _types = {
        'workflow_run_name': 'str',
        'workflow_id': 'str',
        'workflow_version': 'str',
        'workflow_input': 'str',
        'workflow_engine_parameters': 'str',
        'timestamp': 'datetime'
    }

    _attribute_map = {
        'workflow_run_name': 'workflow_run_name',
        'workflow_id': 'workflow_id',
        'workflow_version': 'workflow_version',
        'workflow_input': 'workflow_input',
        'workflow_engine_parameters': 'workflow_engine_parameters',
        'timestamp': 'timestamp'
    }

    def __init__(self, workflow_run_name=None, workflow_id=None, workflow_version=None, workflow_input=None, workflow_engine_parameters=None, timestamp=None):  # noqa: E501
        self._workflow_run_name = None
        self._workflow_id = None
        self._workflow_version = None
        self._workflow_input = None
        self._workflow_engine_parameters = None
        self._timestamp = None
        self.discriminator = None
        self.workflow_run_name = workflow_run_name
        self.workflow_id = workflow_id
        self.workflow_version = workflow_version
        self.workflow_input = workflow_input
        self.workflow_engine_parameters = workflow_engine_parameters
        self.timestamp = timestamp


    @property
    def workflow_run_name(self):

        return self._workflow_run_name

    @workflow_run_name.setter
    def workflow_run_name(self, workflow_run_name):


        self._workflow_run_name = workflow_run_name


    @property
    def workflow_id(self):

        return self._workflow_id

    @workflow_id.setter
    def workflow_id(self, workflow_id):


        self._workflow_id = workflow_id


    @property
    def workflow_version(self):

        return self._workflow_version

    @workflow_version.setter
    def workflow_version(self, workflow_version):


        self._workflow_version = workflow_version


    @property
    def workflow_input(self):

        return self._workflow_input

    @workflow_input.setter
    def workflow_input(self, workflow_input):


        self._workflow_input = workflow_input


    @property
    def workflow_engine_parameters(self):

        return self._workflow_engine_parameters

    @workflow_engine_parameters.setter
    def workflow_engine_parameters(self, workflow_engine_parameters):


        self._workflow_engine_parameters = workflow_engine_parameters


    @property
    def timestamp(self):

        return self._timestamp

    @timestamp.setter
    def timestamp(self, timestamp):


        self._timestamp = timestamp

    def to_dict(self):
        result = {}

        for attr, _ in six.iteritems(self._types):
            value = getattr(self, attr)
            if isinstance(value, list):
                result[attr] = list(map(
                    lambda x: x.to_dict() if hasattr(x, "to_dict") else x,
                    value
                ))
            elif hasattr(value, "to_dict"):
                result[attr] = value.to_dict()
            elif isinstance(value, dict):
                result[attr] = dict(map(
                    lambda item: (item[0], item[1].to_dict())
                    if hasattr(item[1], "to_dict") else item,
                    value.items()
                ))
            else:
                result[attr] = value
        if issubclass(Event, dict):
            for key, value in self.items():
                result[key] = value

        return result

    def to_str(self):
        return pprint.pformat(self.to_dict())

    def __repr__(self):
        return self.to_str()

    def __eq__(self, other):
        if not isinstance(other, Event):
            return False

        return self.__dict__ == other.__dict__

    def __ne__(self, other):
        return not self == other

