# coding: utf-8
import pprint
import re  # noqa: F401

import six
from enum import Enum

class Event(object):


    _types = {
        'workflow_run_id': 'str',
        'workflow_run_name': 'str',
        'status': 'str',
        'timestamp': 'datetime'
    }

    _attribute_map = {
        'workflow_run_id': 'workflow_run_id',
        'workflow_run_name': 'workflow_run_name',
        'status': 'status',
        'timestamp': 'timestamp'
    }

    def __init__(self, workflow_run_id=None, workflow_run_name=None, status=None, timestamp=None):  # noqa: E501
        self._workflow_run_id = None
        self._workflow_run_name = None
        self._status = None
        self._timestamp = None
        self.discriminator = None
        self.workflow_run_id = workflow_run_id
        self.workflow_run_name = workflow_run_name
        self.status = status
        self.timestamp = timestamp


    @property
    def workflow_run_id(self):

        return self._workflow_run_id

    @workflow_run_id.setter
    def workflow_run_id(self, workflow_run_id):


        self._workflow_run_id = workflow_run_id


    @property
    def workflow_run_name(self):

        return self._workflow_run_name

    @workflow_run_name.setter
    def workflow_run_name(self, workflow_run_name):


        self._workflow_run_name = workflow_run_name


    @property
    def status(self):

        return self._status

    @status.setter
    def status(self, status):


        self._status = status


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

