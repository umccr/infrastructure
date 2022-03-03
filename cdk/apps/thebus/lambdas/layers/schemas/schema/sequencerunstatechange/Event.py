# coding: utf-8
import pprint
import re  # noqa: F401

import six
from enum import Enum

class Event(object):


    _types = {
        'sequence_run_id': 'str',
        'sequence_run_name': 'str',
        'gds_volume_name': 'str',
        'gds_folder_path': 'str',
        'status': 'str',
        'timestamp': 'datetime'
    }

    _attribute_map = {
        'sequence_run_id': 'sequence_run_id',
        'sequence_run_name': 'sequence_run_name',
        'gds_volume_name': 'gds_volume_name',
        'gds_folder_path': 'gds_folder_path',
        'status': 'status',
        'timestamp': 'timestamp'
    }

    def __init__(self, sequence_run_id=None, sequence_run_name=None, gds_volume_name=None, gds_folder_path=None, status=None, timestamp=None):  # noqa: E501
        self._sequence_run_id = None
        self._sequence_run_name = None
        self._gds_volume_name = None
        self._gds_folder_path = None
        self._status = None
        self._timestamp = None
        self.discriminator = None
        self.sequence_run_id = sequence_run_id
        self.sequence_run_name = sequence_run_name
        self.gds_volume_name = gds_volume_name
        self.gds_folder_path = gds_folder_path
        self.status = status
        self.timestamp = timestamp


    @property
    def sequence_run_id(self):

        return self._sequence_run_id

    @sequence_run_id.setter
    def sequence_run_id(self, sequence_run_id):


        self._sequence_run_id = sequence_run_id


    @property
    def sequence_run_name(self):

        return self._sequence_run_name

    @sequence_run_name.setter
    def sequence_run_name(self, sequence_run_name):


        self._sequence_run_name = sequence_run_name


    @property
    def gds_volume_name(self):

        return self._gds_volume_name

    @gds_volume_name.setter
    def gds_volume_name(self, gds_volume_name):


        self._gds_volume_name = gds_volume_name


    @property
    def gds_folder_path(self):

        return self._gds_folder_path

    @gds_folder_path.setter
    def gds_folder_path(self, gds_folder_path):


        self._gds_folder_path = gds_folder_path


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

