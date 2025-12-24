// Google Sheets JS script to generate internal SubjectID values
// Should be attached to the UMCCR_Library_Tracking_MetaData Google Spreadsheet

var YEARS = ['2019', '2020', '2021', '2022', '2023', '2018', '2017', '2024', '2025', '2026'];  // make sure sheets with new data are listed last!
var SBJ_ID_PREFIX = "SBJ"; // subject ID prefix (before zero filled running number)
var SBJ_ID_INT_LEN = 5;    // length of the integer part of subject ID (used for zero filling)
var SBJ_COL_IDX = 0;
var EXT_SBJ_COL_IDX = 0;

// function called when spreadsheet is opened
function onOpen() {
  var ui = SpreadsheetApp.getUi();
  ui.createMenu('UMCCR')
      .addItem('Generate internal SubjectIDs', 'menuCreateIds')
      .addItem('Show next internal SubjectID', 'showNextSubjectId')
      .addToUi();
}

// Initialise Indexes and Polyfills
function init() {
  loadPolyfills();
  // retrieve the column index of the subject id column (note: 0 based, hence +1)
}

function init_column_indexes(year) {
  Logger.log('Active year: ' + year)
  var dataRange = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(year).getDataRange();
  SBJ_COL_IDX = dataRange.getValues()[0].indexOf('SubjectID') + 1;
  Logger.log('Subject ID column: ' + SBJ_COL_IDX )
  EXT_SBJ_COL_IDX = dataRange.getValues()[0].indexOf('ExternalSubjectID') + 1;
  Logger.log('ExternalSubjectID column: ' + EXT_SBJ_COL_IDX )  
}

function showNextSubjectId() {
  init()

  var nextId = getNextIdCnt();
  //SpreadsheetApp.getUi().alert('Next SubjectID: ' + nextId);
  Browser.msgBox('Next SubjectID: ' + nextId)
}

// create a new menu item for the spreadsheet
function menuCreateIds() {
  init()

  var itemsCreated = createNewIntSubIds();
  //Browser.msgBox("New subject IDs created: " + itemsCreated);
}

// load polyfills for missing functions
function loadPolyfills() {
  // https://vanillajstoolkit.com/polyfills/stringstartswith/
  if (!String.prototype.startsWith) {
	String.prototype.startsWith = function(searchString, position){
		return this.substr(position || 0, searchString.length) === searchString;
	};
  }

}


// zero fill integer
function zerofill(num, size) {
  var s = num+"";
  while (s.length < size) s = "0" + s;
  return s;
}

// extract the integer part of the subject ID
function getIntFromId(subjectId) {
  subjectId = String(subjectId).trim();
  if (subjectId.startsWith(SBJ_ID_PREFIX)) {
    return parseInt(subjectId.substring(SBJ_ID_PREFIX.length), 10);
  } else {
    if (subjectId.length > 0) {
      var msg = "ERROR: subject identifier with wrong prefix (expected SBJ): " + subjectId ;
      Logger.log(msg);
      console.error(msg);
      throw msg;
    }
    // else: ignore
  }
  return 0;
}

// find the lastest (biggest) SBJ for the given year
function getNextIdCntByYear(year) {
  cnt = 0;
  init_column_indexes(year)
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(year);
  // sheet.getRange(row, column, numRows, numColumns)
  var data = sheet.getRange(2, SBJ_COL_IDX, sheet.getLastRow(), 1).getValues();
  for (var i = 0; i < data.length; i++) {
      fullSubId = String(data[i][0]).trim()
      var intSubId = getIntFromId(fullSubId);
      if (intSubId > cnt) {
          Logger.log("BIGGER");
          cnt = intSubId;
      }
  }
  return cnt;
}

// find the next subject ID, by finding the largest integer part of the ID
function getNextIdCnt() {
    Logger.log("SBJ column index: " + SBJ_COL_IDX)
    var last = 0;
    for (let i in YEARS) {
      cnt = getNextIdCntByYear(YEARS[i])
      if (cnt > last) {
        last = cnt;
      }
    }
    return ++last;
}

function createNewIntSubIdsByYear(year, subjectHash, cnt) {
  init_column_indexes(year);
  // Find all subject IDs and create new internal ones where they don't exist
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(year);
  var sbjDataRange = sheet.getRange(2, SBJ_COL_IDX, sheet.getLastRow() - 1, 1);
  var sbjData = sbjDataRange.getValues();
  var extSbjData = sheet.getRange(2, EXT_SBJ_COL_IDX, sheet.getLastRow() - 1, 1).getValues();

  for (var i = 0; i < sbjData.length; i++) {
    // does not handle differnt internal IDs for the same external ID!!
      var intSubId = String(sbjData[i][0]).trim();
      var extSubId = String(extSbjData[i][0]).trim();
      if (extSubId in subjectHash) {
          var storedIntSubId = subjectHash[extSubId];
          Logger.log("Internal ID already known for " + extSubId + " : " + storedIntSubId);
          if (intSubId && intSubId != storedIntSubId) {
              Logger.log("ERROR: overwriting existing identifier! " + storedIntSubId + "->" + intSubId);
              subjectHash[extSubId] = intSubId;
              sbjData[i][0] = intSubId;
              // TODO: may need some further logic to select the "best" identifier for that subject, or allow user to select one
          } else {
              sbjData[i][0] = storedIntSubId;
          }
      } else {
          if (!extSubId) {  // skip empty values
              continue;
          }
          if (intSubId) {
              Logger.log("Internal ID already present:" + intSubId);
              subjectHash[extSubId] = intSubId;
          } else {
              Logger.log("New subject " + extSubId + ". Creating new internal ID.");
              var nId = SBJ_ID_PREFIX + zerofill(cnt, SBJ_ID_INT_LEN);
              subjectHash[extSubId] = nId;
              sbjData[i][0] = nId;
              cnt++;
          }
      }
  }
  sbjDataRange.setValues(sbjData);
  return cnt;
}

function createNewIntSubIds() {
    var cnt = getNextIdCnt();
    Logger.log("Next ID cnt: "  + cnt);
    var startCnt = cnt;
    var subjectHash = {};

    for (let i in YEARS) {
      cnt = createNewIntSubIdsByYear(YEARS[i], subjectHash, cnt)
    }

    Logger.log("New IDs created: " + (cnt - startCnt));
    return (cnt - startCnt);
}
