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
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Process", "OnRequest started for file: " _ pRequest.FileName)
        
        // Initialize response with request data
        Set pResponse.FileName = pRequest.FileName
        Set pResponse.FileHash = pRequest.FileHash
        Set pResponse.Status = "processing"
        Set pResponse.ProcessedAt = ##class(Demo.Util.Logger).NowISO()
        
        // Record processing start time
        Set startTime = $ZHorolog
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Process", "Starting processing of file: " _ pRequest.FileName)
        Do ##class(Demo.Util.Logger).WriteFileLog("PROCESS_START " _ pRequest.FileName _ " hash=" _ pRequest.FileHash)
        
        // Note: File validation is done by FileService, so we skip file existence check here
        // The file may have been moved to WIP directory by the time we process it
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Process", "About to parse CSV")
        
        // Parse CSV file and validate structure
        Set recordCount = 0
        Kill csvData
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Process", "About to call ParseCSVFile for: " _ pRequest.FilePath)
        
        Set parseStatus = ..ParseCSVFile(pRequest.FilePath, .csvData, .recordCount)
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.Process", "ParseCSVFile returned status: " _ $System.Status.GetErrorText(parseStatus) _ ", recordCount: " _ recordCount)
        
        If $$$ISERR(parseStatus) {
            Set pResponse.Status = "error"
            Set pResponse.ErrorMessage = "CSV parsing failed: " _ $System.Status.GetErrorText(parseStatus)
            Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Process", pResponse.ErrorMessage)
            Return $$$OK
        }
        
        // Debug: Check if csvData is properly initialized
        If '$Data(csvData) {
            Set pResponse.Status = "error"
            Set pResponse.ErrorMessage = "CSV data not initialized after parsing"
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
        
        // Initialize database operation counters
        Set mysqlOK = 0, mysqlFailed = 0, mysqlError = ""
        Set postgresOK = 0, postgresFailed = 0, postgresError = ""
        
        // Create database request for both operations
        Set dbRequest = ##class(Demo.Msg.DatabaseInsertRequest).%New()
        Set dbRequest.RequestId = $System.Util.CreateGUID()
        Set dbRequest.TotalRecords = recordCount
        Set dbRequest.SubmittedAt = ##class(Demo.Util.Logger).NowISO()
        Set dbRequest.FileName = pRequest.FileName
        Set dbRequest.FileHash = pRequest.FileHash
        
        // Copy CSV data to request
        If $Data(csvData("header")) {
            Set dbRequest.CSVHeader = csvData("header")
        }
        
        For i=1:1:recordCount {
            If $Data(csvData("data", i)) {
                Do dbRequest.CSVRecords.SetAt(csvData("data", i), i)
            }
        }
        
    // Process MySQL insertion (real operation)
    Set mysqlStatus = ..ProcessDatabaseInsertion("MySQL", ..MySQLTarget, .csvData, recordCount, pRequest.FileName, pRequest.FileHash, .mysqlOK, .mysqlFailed, .mysqlError)
        
    Set pResponse.MySQLRecordsOK = mysqlOK
    Set pResponse.MySQLRecordsFailed = mysqlFailed
        
    // Process PostgreSQL insertion (real operation)
    Set postgresStatus = ..ProcessDatabaseInsertion("PostgreSQL", ..PostgreSQLTarget, .csvData, recordCount, pRequest.FileName, pRequest.FileHash, .postgresOK, .postgresFailed, .postgresError)
        
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
        Set duration = $Piece(endTime, ",", 2) - $Piece(startTime, ",", 2)  // Simple seconds calculation
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
        // Note: Skip file existence check as file may have been moved by FileService
        // File validation is already done by FileService before sending to Process
        
        // Initialize csvData explicitly
        Set csvData("recordCount") = 0
        Set csvData("hasHeader") = 0
        
        // Simplified file reading - just read all content first
        Set fileContent = ""
        Set stream = ##class(%FileCharacterStream).%New()
        Set stream.Filename = filePath
        
        // Check if stream could open the file
        If stream.Size = 0 {
            Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.Process", "Cannot read file or file is empty: " _ filePath)
            Return $$$ERROR(5001, "Cannot read file: " _ filePath)
        }
        
        // Read entire file content
        While 'stream.AtEnd {
            Set fileContent = fileContent _ stream.Read(1000)
        }
        
        // Split into lines
        Set lineCount = $Length(fileContent, $C(10))  // Split by newline
        Set hasHeader = 0
        
        For i = 1:1:lineCount {
            Set line = $Piece(fileContent, $C(10), i)
            
            // Remove carriage return if present
            Set line = $ZStrip(line, ">", $C(13))
            
            // Skip empty lines
            If $ZStrip(line, "<>W") = "" Continue
            
            // Parse CSV line
            Set fieldCount = $Length(line, ",")
            If fieldCount < 2 Continue
            
            // First line with content is header if it contains non-numeric first field
            If 'hasHeader && i = 1 {
                Set firstField = $Piece(line, ",", 1)
                If firstField '= "" && '$IsValidNum(firstField) {
                    Set hasHeader = 1
                    Set csvData("header") = line
                    Set csvData("hasHeader") = 1
                    Continue
                }
            }
            
            // Store data row
            Set recordCount = recordCount + 1
            Set csvData("data", recordCount) = line
            Set csvData("line", recordCount) = i
        }
        
        // Update final counts
        Set csvData("recordCount") = recordCount
        
        // Validate we have some data
        If recordCount = 0 {
            Return $$$ERROR(5001, "No valid data records found in CSV file")
        }
        
    } Catch ex {
        Set status = ex.AsStatus()
        // Simplified error handling without logging that might fail
    }
    
    Return status
}

/// Process insertion into specified database
Method ProcessDatabaseInsertion(dbType As %String, target As %String, ByRef csvData, recordCount As %Integer, fileName As %String, fileHash As %String, Output recordsOK As %Integer, Output recordsFailed As %Integer, Output errorMsg As %String) As %Status
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
        Set dbRequest.FileName = fileName
        Set dbRequest.FileHash = fileHash
        
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