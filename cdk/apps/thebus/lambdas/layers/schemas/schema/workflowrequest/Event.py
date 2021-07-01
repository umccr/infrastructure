# coding: utf-8
import pprint
import re  # noqa: F401

import six
from enum import Enum

class Event(object):


    _types = {
        'workflow_type': 'str',
        'subject_id': 'str',
        'library_id': 'str',
        'seq_run_name': 'str'
    }

    _attribute_map = {
        'workflow_type': 'workflow_type',
        'subject_id': 'subject_id',
        'library_id': 'library_id',
        'seq_run_name': 'seq_run_name'
    }

    def __init__(self, workflow_type=None, subject_id=None, library_id=None, seq_run_name=None):  # noqa: E501
        self._workflow_type = None
        self._subject_id = None
        self._library_id = None
        self._seq_run_name = None
        self.discriminator = None
        self.workflow_type = workflow_type
        self.subject_id = subject_id
        self.library_id = library_id
        self.seq_run_name = seq_run_name


    @property
    def workflow_type(self):

        return self._workflow_type

    @workflow_type.setter
    def workflow_type(self, workflow_type):


        self._workflow_type = workflow_type


    @property
    def subject_id(self):

        return self._subject_id

    @subject_id.setter
    def subject_id(self, subject_id):


        self._subject_id = subject_id


    @property
    def library_id(self):

        return self._library_id

    @library_id.setter
    def library_id(self, library_id):


        self._library_id = library_id


    @property
    def seq_run_name(self):

        return self._seq_run_name

    @seq_run_name.setter
    def seq_run_name(self, seq_run_name):


        self._seq_run_name = seq_run_name

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

