# -*- coding: utf-8 -*-

"""trigger_wts_report unit test

(Run suite with pytest)
pytest

(Run suite)
python -m unittest

(Run individual test case)
python -m unittest tests.test_trigger_wts_report.TriggerWtsReportTests.test_lambda_handler
"""
import os
import unittest
import uuid
from datetime import datetime, timezone

from botocore.client import BaseClient
from mockito import unstub, when
from mockito.mocking import mock

from lambdas import trigger_wts_report
from . import _logger


class TriggerWtsReportTests(unittest.TestCase):

    def setUp(self) -> None:
        os.environ['JOBNAME_PREFIX'] = "MOCK_JOBNAME_PREFIX_wts_report"
        os.environ['JOBDEF'] = "MOCK_JOBDEF_arn:aws:batch:ap-southeast-2:123456789:job-definition/wts_report_job_dev:15"

    def tearDown(self) -> None:
        unstub()

    def test_lambda_handler(self):
        zulu_now = str(datetime.now(timezone.utc).isoformat()[:-6] + 'Z')

        mock_event = {
            'dataDirWGS': 'ProjectName/SBJ99999/WGS/2020-03-04/umccrised/SBJ987654__SBJ987654_MDX999999_L9999999',
            'dataDirWTS': 'ProjectName/SBJ99999/WTS/2020-04-15/final/SBJ99999_MDX999999_L9999999',
            'refDataset': 'LAML', 'dataBucket': 'umccr-primary-data', 'resultBucket': 'umccr-temp'
        }

        mock_list_response = {
            'Contents': [
                {
                    'Key': 'ProjectName/SBJ99999/WTS/2020-04-15/final/SBJ99999_MDX999999_L9999999'
                           '/SBJ99999_MDX999999_L9999999-arriba-discarded-fusions.tsv',
                    'LastModified': zulu_now,
                    'ETag': '"b59c4096d775760cf8b06dbfbd419445-5"',
                    'Size': 35633574, 'StorageClass': 'INTELLIGENT_TIERING'
                },
            ]
        }

        mock_job_id = str(uuid.uuid4())
        mock_submit_job_response = {
            'ResponseMetadata': {
                'RequestId': str(uuid.uuid4()),
                'HTTPStatusCode': 200,
                'RetryAttempts': 0
            },
            'jobName': 'MOCK_JOBNAME_PREFIX_wts_report_umccr-primary-data---ProjectName_SBJ99999_WTS_2020-04'
                       '-15_final_SBJ99999_MDX999999_L9999999',
            'jobId': mock_job_id
        }

        mock_client = mock(spec=BaseClient)
        when(trigger_wts_report.boto3).client(...).thenReturn(mock_client)
        when(mock_client).list_objects(...).thenReturn(mock_list_response)
        when(mock_client).submit_job(...).thenReturn(mock_submit_job_response)

        try:
            resp = trigger_wts_report.lambda_handler(mock_event, None)
            _logger.info(resp)
            self.assertEqual(mock_job_id, resp['jobId'])
        except Exception as e:
            # assert raise no exception, otherwise fail the test
            self.fail(e)
