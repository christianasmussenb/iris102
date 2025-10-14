/// Demo.Process - Business Process for CSV file processing coordination
Class Demo.Process Extends Ens.BusinessProcess [ ClassType = persistent ]
{

/// MySQL Operation target
Property MySQLTarget As %String [ InitialExpression = "MySQLOperation" ];

/// PostgreSQL Operation target
Property PostgreSQLTarget As %String [ InitialExpression = "PostgreSQLOperation" ];

/// Maximum retry attempts for failed operations
Property MaxRetries As %Integer [ InitialExpression = 3 ];

/// Timeout for database operations (seconds)
Property OperationTimeout As %Integer [ InitialExpression = 180 ];

/// Process file processing request
Method OnRequest(pRequest As Demo.Msg.FileProcessRequest, Output pResponse As Demo.Msg.FileProcessResponse) As %Status
{
    Set status = $$$OK
    Set pResponse = ##class(Demo.Msg.FileProcessResponse).%New()
    
    Try {
        // Initialize response with request data
        Set pResponse.FileName = pRequest.FileName
        Set pResponse.FileHash = pRequest.FileHash
        Set pResponse.Status = "processing"
        Set pResponse.ProcessedAt = ##class(Demo.Util.Logger).NowISO()
        
        // Record processing start time
        Set startTime = $ZHorolog
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Process", "Starting processing of file: " _ pRequest.FileName)
        Do ##class(Demo.Util.Logger).WriteFileLog("PROCESS_START " _ pRequest.FileName _ " hash=" _ pRequest.FileHash)
        
        // Validate file exists and is readable
        If '##class(%File).Exists(pRequest.FilePath) {
            Set pResponse.Status = "error"
            Set pResponse.ErrorMessage = "File not found: " _ pRequest.FilePath
            Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Process", pResponse.ErrorMessage)
            Return $$$OK
        }
        
        // Parse CSV file and validate structure
        Set parseStatus = ..ParseCSVFile(pRequest.FilePath, .csvData, .recordCount)
        If $$$ISERR(parseStatus) {
            Set pResponse.Status = "error"
            Set pResponse.ErrorMessage = "CSV parsing failed: " _ $System.Status.GetErrorText(parseStatus)
            Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Process", pResponse.ErrorMessage)
            Return $$$OK
        }
        
        Set pResponse.TotalRecords = recordCount
        Do ##class(Demo.Util.Logger).WriteFileLog("PARSED " _ pRequest.FileName _ " records=" _ recordCount)
        
        // If no records, mark as completed
        If recordCount = 0 {
            Set pResponse.Status = "ok"
            Set pResponse.ErrorMessage = "File is empty or contains no valid records"
            Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.Process", "Empty file processed: " _ pRequest.FileName)
            Return $$$OK
        }
        
        // Process MySQL insertion
        Set mysqlStatus = ..ProcessDatabaseInsertion("MySQL", ..MySQLTarget, csvData, recordCount, .mysqlOK, .mysqlFailed, .mysqlError)
        Set pResponse.MySQLRecordsOK = mysqlOK
        Set pResponse.MySQLRecordsFailed = mysqlFailed
        
        // Process PostgreSQL insertion
        Set postgresStatus = ..ProcessDatabaseInsertion("PostgreSQL", ..PostgreSQLTarget, csvData, recordCount, .postgresOK, .postgresFailed, .postgresError)
        Set pResponse.PostgreSQLRecordsOK = postgresOK
        Set pResponse.PostgreSQLRecordsFailed = postgresFailed
        
        // Determine overall status
        Set totalOK = mysqlOK + postgresOK
        Set totalFailed = mysqlFailed + postgresFailed
        Set totalExpected = recordCount * 2  // Records should go to both databases
        
        If totalFailed = 0 {
            Set pResponse.Status = "ok"
        } ElseIf totalOK > 0 {
            Set pResponse.Status = "partial"
            Set pResponse.ErrorMessage = "Some records failed: MySQL(" _ mysqlFailed _ ") PostgreSQL(" _ postgresFailed _ ")"
        } Else {
            Set pResponse.Status = "failed"
            Set pResponse.ErrorMessage = "All database operations failed"
        }
        
        // Calculate processing duration
        Set endTime = $ZHorolog
        Set duration = ##class(Demo.Util.Logger).CalculateDuration(startTime, endTime)
        Set pResponse.ProcessingDuration = duration
        
        // Log final result
        Set logMsg = "PROCESS_END " _ pRequest.FileName
        Set logMsg = logMsg _ " status=" _ pResponse.Status
        Set logMsg = logMsg _ " total=" _ recordCount
        Set logMsg = logMsg _ " mysql_ok=" _ mysqlOK _ " mysql_failed=" _ mysqlFailed
        Set logMsg = logMsg _ " postgres_ok=" _ postgresOK _ " postgres_failed=" _ postgresFailed
        Set logMsg = logMsg _ " duration=" _ duration _ "s"
        
        Do ##class(Demo.Util.Logger).WriteFileLog(logMsg)
        
        If pResponse.Status = "ok" {
            Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Process", "File processed successfully: " _ pRequest.FileName)
        } ElseIf pResponse.Status = "partial" {
            Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.Process", "File processed with errors: " _ pRequest.FileName _ " - " _ pResponse.ErrorMessage)
        } Else {
            Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Process", "File processing failed: " _ pRequest.FileName _ " - " _ pResponse.ErrorMessage)
        }
        
    } Catch ex {
        Set status = ex.AsStatus()
        Set pResponse.Status = "error"
        Set pResponse.ErrorMessage = "Processing exception: " _ ex.DisplayString()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Process", "Exception processing " _ pRequest.FileName _ ": " _ ex.DisplayString())
        Do ##class(Demo.Util.Logger).WriteFileLog("PROCESS_ERROR " _ pRequest.FileName _ " error=" _ ex.DisplayString())
    }
    
    Return $$$OK
}

/// Parse CSV file into structured data
Method ParseCSVFile(filePath As %String, Output csvData, Output recordCount As %Integer) As %Status
{
    Set status = $$$OK
    Set recordCount = 0
    Kill csvData
    
    Try {
        // Open file for reading
        Set file = ##class(%File).%New(filePath)
        Set status = file.Open("R")
        If $$$ISERR(status) {
            Return status
        }
        
        Set lineNumber = 0
        Set hasHeader = 0
        
        While 'file.AtEnd {
            Set line = file.ReadLine()
            Set lineNumber = lineNumber + 1
            
            // Skip empty lines
            If $ZStrip(line, "<>W") = "" Continue
            
            // Parse CSV line (simple implementation - could be enhanced for complex CSV)
            Set fieldCount = $Length(line, ",")
            If fieldCount < 2 {
                Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.Process", "Skipping invalid line " _ lineNumber _ " in " _ filePath)
                Continue
            }
            
            // First line with content is header if it contains non-numeric first field
            If 'hasHeader && lineNumber = 1 {
                Set firstField = $Piece(line, ",", 1)
                If firstField '= "" && '$IsValidNum(firstField) {
                    Set hasHeader = 1
                    Set csvData("header") = line
                    Continue
                }
            }
            
            // Store data row
            Set recordCount = recordCount + 1
            Set csvData("data", recordCount) = line
            Set csvData("line", recordCount) = lineNumber
        }
        
        Do file.Close()
        
        // Validate we have some data
        If recordCount = 0 {
            Return $$$ERROR(5001, "No valid data records found in CSV file")
        }
        
        Set csvData("recordCount") = recordCount
        Set csvData("hasHeader") = hasHeader
        
    } Catch ex {
        Set status = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Process", "Error parsing CSV file " _ filePath _ ": " _ ex.DisplayString())
        Try { Do file.Close() } Catch {}
    }
    
    Return status
}

/// Process insertion into specified database
Method ProcessDatabaseInsertion(dbType As %String, target As %String, ByRef csvData, recordCount As %Integer, Output recordsOK As %Integer, Output recordsFailed As %Integer, Output errorMsg As %String) As %Status
{
    Set status = $$$OK
    Set recordsOK = 0
    Set recordsFailed = 0
    Set errorMsg = ""
    
    Try {
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Process", "Starting " _ dbType _ " insertion for " _ recordCount _ " records")
        
        // Create database insert request
        Set dbRequest = ##class(Demo.Msg.DatabaseInsertRequest).%New()
        Set dbRequest.DatabaseType = dbType
        Set dbRequest.TotalRecords = recordCount
        Set dbRequest.RequestId = ##class(Demo.Util.Logger).GenerateUniqueId()
        Set dbRequest.SubmittedAt = ##class(Demo.Util.Logger).NowISO()
        
        // Copy CSV data to request
        If $Data(csvData("header")) {
            Set dbRequest.CSVHeader = csvData("header")
        }
        
        For i=1:1:recordCount {
            If $Data(csvData("data", i)) {
                Do dbRequest.CSVRecords.SetAt(csvData("data", i), i)
            }
        }
        
        // Send request with retry logic
        Set retryCount = 0
        Set completed = 0
        
        While 'completed && (retryCount < ..MaxRetries) {
            Set retryCount = retryCount + 1
            
            If retryCount > 1 {
                Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Process", "Retry " _ retryCount _ " for " _ dbType _ " insertion")
                // Wait before retry (exponential backoff)
                Hang (retryCount * 2)
            }
            
            Set status = ..SendRequestSync(target, dbRequest, .dbResponse, ..OperationTimeout)
            
            If $$$ISERR(status) {
                Set errorMsg = "Failed to send request to " _ dbType _ ": " _ $System.Status.GetErrorText(status)
                Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Process", errorMsg)
                Continue
            }
            
            If '$IsObject(dbResponse) || 'dbResponse.%IsA("Demo.Msg.DatabaseInsertResponse") {
                Set errorMsg = "Invalid response from " _ dbType _ " operation"
                Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Process", errorMsg)
                Continue
            }
            
            // Process successful response
            Set recordsOK = dbResponse.RecordsInserted
            Set recordsFailed = dbResponse.RecordsFailed
            Set completed = 1
            
            If dbResponse.Status '= "ok" {
                Set errorMsg = dbType _ " operation completed with status: " _ dbResponse.Status
                If dbResponse.ErrorMessage '= "" {
                    Set errorMsg = errorMsg _ " - " _ dbResponse.ErrorMessage
                }
            }
            
            Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Process", dbType _ " insertion completed: " _ recordsOK _ " OK, " _ recordsFailed _ " failed")
        }
        
        If 'completed {
            Set recordsFailed = recordCount
            Set errorMsg = dbType _ " operation failed after " _ ..MaxRetries _ " retries"
            Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Process", errorMsg)
        }
        
    } Catch ex {
        Set status = ex.AsStatus()
        Set recordsFailed = recordCount
        Set errorMsg = dbType _ " processing exception: " _ ex.DisplayString()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Process", errorMsg)
    }
    
    Return status
}

/// Get process statistics
Method GetStats() As %String
{
    Set stats = ""
    
    Try {
        Set stats = stats _ "Process: Demo.Process" _ $C(13,10)
        Set stats = stats _ "MySQL Target: " _ ..MySQLTarget _ $C(13,10)
        Set stats = stats _ "PostgreSQL Target: " _ ..PostgreSQLTarget _ $C(13,10)
        Set stats = stats _ "Max Retries: " _ ..MaxRetries _ $C(13,10)
        Set stats = stats _ "Operation Timeout: " _ ..OperationTimeout _ "s" _ $C(13,10)
        
    } Catch ex {
        Set stats = "Error getting stats: " _ ex.DisplayString()
    }
    
    Return stats
}

}