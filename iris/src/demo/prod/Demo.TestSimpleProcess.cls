/// Demo.TestSimpleProcess - Simplified Business Process for testing
Class Demo.TestSimpleProcess Extends Ens.BusinessProcess [ ClassType = persistent ]
{

/// Process file processing request with direct simulation
Method OnRequest(pRequest As Demo.Msg.FileProcessRequest, Output pResponse As Demo.Msg.FileProcessResponse) As %Status
{
    Set status = $$$OK
    Set pResponse = ##class(Demo.Msg.FileProcessResponse).%New()
    
    Try {
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.TestSimpleProcess", "OnRequest started for file: " _ pRequest.FileName)
        
        // Initialize response with request data
        Set pResponse.FileName = pRequest.FileName
        Set pResponse.FileHash = pRequest.FileHash
        Set pResponse.Status = "processing"
        Set pResponse.ProcessedAt = ##class(Demo.Util.Logger).NowISO()
        
        // Parse the CSV file
        Set parseStatus = ..ParseCSVFile(pRequest.FilePath, .csvData, .recordCount)
        
        If $$$ISERR(parseStatus) {
            Set pResponse.Status = "error"
            Set pResponse.ErrorMessage = "Failed to parse CSV: " _ $System.Status.GetErrorText(parseStatus)
            Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.TestSimpleProcess", "Parse error: " _ pResponse.ErrorMessage)
            Return $$$OK
        }
        
        Set pResponse.TotalRecords = recordCount
        Do ##class(Demo.Util.Logger).WriteFileLog("PARSED " _ pRequest.FileName _ " records=" _ recordCount)
        
        // If no records, mark as completed
        If recordCount = 0 {
            Set pResponse.Status = "ok"
            Set pResponse.ErrorMessage = "File is empty or contains no valid records"
            Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.TestSimpleProcess", "Empty file processed: " _ pRequest.FileName)
            Return $$$OK
        }
        
        // Simulate database operations directly without complex messaging
        Set mysqlOK = 0, mysqlFailed = 0
        Set postgresOK = 0, postgresFailed = 0
        
        // Process each record for MySQL simulation
        For i=1:1:recordCount {
            If $Data(csvData("data", i)) {
                Set csvLine = csvData("data", i)
                Set simStatus = ##class(Demo.SimpleOperation).SimulateInsertCSVRecord(csvLine, pRequest.FileName, pRequest.FileHash)
                If $$$ISOK(simStatus) {
                    Set mysqlOK = mysqlOK + 1
                } Else {
                    Set mysqlFailed = mysqlFailed + 1
                }
            }
        }
        
        // Process each record for PostgreSQL simulation
        For i=1:1:recordCount {
            If $Data(csvData("data", i)) {
                Set csvLine = csvData("data", i)
                Set simStatus = ##class(Demo.SimpleOperation).SimulateInsertCSVRecord(csvLine, pRequest.FileName, pRequest.FileHash)
                If $$$ISOK(simStatus) {
                    Set postgresOK = postgresOK + 1
                } Else {
                    Set postgresFailed = postgresFailed + 1
                }
            }
        }
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.TestSimpleProcess", "MySQL simulation: " _ mysqlOK _ " OK, " _ mysqlFailed _ " failed")
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.TestSimpleProcess", "PostgreSQL simulation: " _ postgresOK _ " OK, " _ postgresFailed _ " failed")
        
        Set pResponse.MySQLRecordsOK = mysqlOK
        Set pResponse.MySQLRecordsFailed = mysqlFailed
        Set pResponse.PostgreSQLRecordsOK = postgresOK
        Set pResponse.PostgreSQLRecordsFailed = postgresFailed
        
        // Determine overall status
        Set totalOK = mysqlOK + postgresOK
        Set totalFailed = mysqlFailed + postgresFailed
        
        If totalFailed = 0 {
            Set pResponse.Status = "ok"
        } ElseIf totalOK > 0 {
            Set pResponse.Status = "partial"
            Set pResponse.ErrorMessage = "Some records failed: MySQL(" _ mysqlFailed _ ") PostgreSQL(" _ postgresFailed _ ")"
        } Else {
            Set pResponse.Status = "failed"
            Set pResponse.ErrorMessage = "All database operations failed"
        }
        
        // Log final result
        Set logMsg = "PROCESS_END " _ pRequest.FileName
        Set logMsg = logMsg _ " status=" _ pResponse.Status
        Set logMsg = logMsg _ " total=" _ recordCount
        Set logMsg = logMsg _ " mysql_ok=" _ mysqlOK _ " mysql_failed=" _ mysqlFailed
        Set logMsg = logMsg _ " postgres_ok=" _ postgresOK _ " postgres_failed=" _ postgresFailed
        
        Do ##class(Demo.Util.Logger).WriteFileLog(logMsg)
        
        If pResponse.Status = "ok" {
            Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.TestSimpleProcess", "File processed successfully: " _ pRequest.FileName)
        } ElseIf pResponse.Status = "partial" {
            Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.TestSimpleProcess", "File processed with errors: " _ pRequest.FileName _ " - " _ pResponse.ErrorMessage)
        } Else {
            Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.TestSimpleProcess", "File processing failed: " _ pRequest.FileName _ " - " _ pResponse.ErrorMessage)
        }
        
    } Catch ex {
        Set status = ex.AsStatus()
        Set pResponse.Status = "error"
        Set pResponse.ErrorMessage = "Process exception: " _ ex.DisplayString()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.TestSimpleProcess", "Exception in OnRequest: " _ ex.DisplayString())
    }
    
    Return status
}

/// Parse CSV file content using basic file I/O
Method ParseCSVFile(filePath As %String, Output csvData, Output recordCount As %Integer) As %Status
{
    Set status = $$$OK
    Set recordCount = 0
    Kill csvData
    Set csvData("header") = ""
    Set csvData("hasHeader") = 0
    Set csvData("recordCount") = 0
    Set hasHeader = 0
    
    Try {
        // Open file for reading
        Set file = ##class(%Stream.FileCharacter).%New()
        Set status = file.LinkToFile(filePath)
        If $$$ISERR(status) {
            Return status
        }
        
        // Read and process line by line
        Set i = 0
        While 'file.AtEnd {
            Set i = i + 1
            Set line = file.ReadLine()
            
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
    }
    
    Return status
}

}