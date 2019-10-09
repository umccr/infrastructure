FROM python:3.7

RUN pip install --upgrade -I pip sample_sheet boto3 pandas gspread openpyxl oauth2client awscli rsa==3.4.2 gspread-pandas

RUN mkdir /scripts/
COPY create-checksums.sh runfolder-check.sh samplesheet-check.py sync-to-s3.sh update-google-lims.py update-stats-sheet.py /scripts/
RUN chmod 755 /scripts/*.sh

