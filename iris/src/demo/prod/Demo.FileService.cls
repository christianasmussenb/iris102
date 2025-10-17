/// Demo.FileService - Business Service for monitoring and processing CSV files
Class Demo.FileService Extends Ens.BusinessService
{

/// Adapter type for file monitoring
Parameter ADAPTER = "EnsLib.File.InboundAdapter";

/// Target for processed files (Business Process)
Property TargetConfigName As %String [ InitialExpression = "FileProcessor" ];

/// Directory paths from environment
Property InputDir As %String [ InitialExpression = "/data/IN" ];

Property OutputDir As %String [ InitialExpression = "/data/OUT" ];

Property LogDir As %String [ InitialExpression = "/data/LOG" ];

Property WIPDir As %String [ InitialExpression = "/data/WIP" ];

/// Initialize service with environment variables
Method OnInit() As %Status
{
    Set status = $$$OK
    
    Try {
        // Use fixed paths to avoid environment variable issues
        Set ..InputDir = "/data/IN"
        Set ..OutputDir = "/data/OUT"
        Set ..LogDir = "/data/LOG"
        Set ..WIPDir = "/data/WIP"
        
        // Ensure directories exist - using simple approach
        Do ##class(%File).CreateDirectoryChain(..InputDir)
        Do ##class(%File).CreateDirectoryChain(..OutputDir)
        Do ##class(%File).CreateDirectoryChain(..LogDir)
        Do ##class(%File).CreateDirectoryChain(..WIPDir)
        
    } Catch ex {
        Set status = ex.AsStatus()
    }
    
    Return status
}

/// Process input file from adapter
Method OnProcessInput(pInput As %FileCharacterStream, pOutput As %RegisteredObject) As %Status
{
    Set status = $$$OK
    Set pOutput = $$$NULLOREF
    
    Try {
        // Get file information
        Set fileName = ##class(%File).GetFilename(pInput.Filename)
        Set filePath = pInput.Filename
        
        // *** NEW ARCHITECTURE: Read CSV content from Stream ***
        Set csvContent = ""
        Do pInput.Rewind()  // Ensure we're at the beginning
        While 'pInput.AtEnd {
            Set csvContent = csvContent _ pInput.Read(32000)
        }
        Set fileSize = $Length(csvContent)
        
        // Debug tracking
        Do ##class(Demo.Util.Logger).DebugFileProcessing(fileName, "START", "size=" _ fileSize _ " bytes (read from stream)")
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.FileService", "Processing file: " _ fileName _ " (" _ fileSize _ " bytes)")
        Do ##class(Demo.Util.Logger).WriteFileLog("START " _ fileName _ " size=" _ fileSize)
        
        // Basic CSV validation on content
        Do ##class(Demo.Util.Logger).DebugFileProcessing(fileName, "VALIDATION", "validating CSV content")
        If csvContent = "" {
            Do ##class(Demo.Util.Logger).DebugFileProcessing(fileName, "VALIDATION_FAILED", "empty content")
            Do ..HandleFileError(fileName, filePath, "invalid", "File is empty")
            Return $$$OK
        }
        Do ##class(Demo.Util.Logger).DebugFileProcessing(fileName, "VALIDATION_OK", "CSV content valid")
        
        // Calculate hash from content
        Do ##class(Demo.Util.Logger).DebugFileProcessing(fileName, "HASH_CALC", "calculating hash from content")
        Set fileHash = $System.Encryption.SHA1Hash(csvContent)
        If fileHash = "" {
            Set fileHash = $ZConvert($Horolog, "L")  // Fallback to timestamp
        }
        Do ##class(Demo.Util.Logger).DebugFileProcessing(fileName, "HASH_OK", "hash=" _ fileHash)
        Do ##class(Demo.Util.Logger).WriteFileLog("HASH " _ fileName _ " hash=" _ fileHash)
        
        // Skip duplicate check for now (can be re-implemented with content-based logic later)
        Do ##class(Demo.Util.Logger).DebugFileProcessing(fileName, "DUPLICATE_CHECK", "skipped (new architecture)")
        
        // Mark file as being processed
        Do ##class(Demo.Util.Logger).DebugFileProcessing(fileName, "MARK_PROCESSING", "marking as processing")
        Do ##class(Demo.Util.Logger).MarkFileAsProcessed(fileName, fileHash, "processing")
        
        // Create request message for Business Process
        Do ##class(Demo.Util.Logger).DebugFileProcessing(fileName, "CREATE_REQUEST", "creating FileProcessRequest with content")
        Set request = ##class(Demo.Msg.FileProcessRequest).%New()
        Set request.CSVContent = csvContent  // *** NEW: Pass content, not path ***
        Set request.FilePath = filePath  // Keep for logging/reference only
        Set request.FileName = fileName
        Set request.FileSize = fileSize
        Set request.FileHash = fileHash
        Set request.DetectedAt = ##class(Demo.Util.Logger).NowISO()
        Set request.RetryCount = 0
        
        // Send to Business Process
        Do ##class(Demo.Util.Logger).DebugFileProcessing(fileName, "SEND_REQUEST", "sending to " _ ..TargetConfigName)
        Set status = ..SendRequestSync(..TargetConfigName, request, .response, 300) // 5 minute timeout
        
        If $$$ISERR(status) {
            Do ##class(Demo.Util.Logger).DebugFileProcessing(fileName, "SEND_FAILED", $System.Status.GetErrorText(status))
            Do ..HandleFileError(fileName, filePath, "error", "Failed to send to Business Process: " _ $System.Status.GetErrorText(status))
            Return $$$OK
        }
        
        // Handle response from Business Process
        If $IsObject(response) && response.%IsA("Demo.Msg.FileProcessResponse") {
            Do ..HandleProcessResponse(fileName, filePath, response)
        } Else {
            Do ..HandleFileError(fileName, filePath, "error", "Invalid response from Business Process")
        }
        
    } Catch ex {
        Set status = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.FileService", "Error processing file " _ $Get(fileName, "unknown") _ ": " _ ex.DisplayString())
        Do ##class(Demo.Util.Logger).WriteFileLog("ERROR " _ $Get(fileName, "unknown") _ " error=" _ ex.DisplayString())
        
        // Try to handle error gracefully
        Do ..HandleFileError($Get(fileName, "unknown"), $Get(filePath, ""), "error", ex.DisplayString())
    }
    
    Return $$$OK  // Always return OK to continue processing other files
}

/// Handle successful response from Business Process
Method HandleProcessResponse(fileName As %String, filePath As %String, response As Demo.Msg.FileProcessResponse) As %Status
{
    Set status = $$$OK
    
    Try {
        // Determine final status based on response
        Set finalStatus = response.Status
        
        // Log processing results
        Set logMsg = "END " _ fileName _ " status=" _ finalStatus
        Set logMsg = logMsg _ " total=" _ response.TotalRecords
        Set logMsg = logMsg _ " mysql_ok=" _ response.MySQLRecordsOK
        Set logMsg = logMsg _ " mysql_failed=" _ response.MySQLRecordsFailed
        Set logMsg = logMsg _ " postgres_ok=" _ response.PostgreSQLRecordsOK
        Set logMsg = logMsg _ " postgres_failed=" _ response.PostgreSQLRecordsFailed
        
        If response.ProcessingDuration '= "" {
            Set logMsg = logMsg _ " duration=" _ response.ProcessingDuration _ "s"
        }
        
        Do ##class(Demo.Util.Logger).WriteFileLog(logMsg)
        
        // Log to Event Log
        If finalStatus = "ok" {
            Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.FileService", "File " _ fileName _ " processed successfully")
        } ElseIf finalStatus = "partial" {
            Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.FileService", "File " _ fileName _ " processed with partial success")
        } Else {
            Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.FileService", "File " _ fileName _ " processing failed: " _ response.ErrorMessage)
        }
        
        // Move file to output directory
        Set status = ..MoveProcessedFile(fileName, filePath, finalStatus)
        
        // Update processed file status
        Do ##class(Demo.Util.Logger).MarkFileAsProcessed(fileName, "", finalStatus)
        
    } Catch ex {
        Set status = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.FileService", "Error handling response for " _ fileName _ ": " _ ex.DisplayString())
    }
    
    Return status
}

/// Handle file processing errors
Method HandleFileError(fileName As %String, filePath As %String, errorStatus As %String, errorMsg As %String) As %Status
{
    Set status = $$$OK
    
    Try {
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.FileService", "File " _ fileName _ " error (" _ errorStatus _ "): " _ errorMsg)
        Do ##class(Demo.Util.Logger).WriteFileLog("END " _ fileName _ " status=" _ errorStatus _ " error=" _ errorMsg)
        
        // Move file to output with error status
        Set status = ..MoveProcessedFile(fileName, filePath, errorStatus)
        
        // Mark as processed with error
        Do ##class(Demo.Util.Logger).MarkFileAsProcessed(fileName, "", errorStatus)
        
    } Catch ex {
        Set status = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.FileService", "Error handling file error for " _ fileName _ ": " _ ex.DisplayString())
    }
    
    Return status
}

/// Move processed file to output directory with timestamp and status
Method MoveProcessedFile(fileName As %String, filePath As %String, status As %String) As %Status
{
    Set result = $$$OK
    
    Try {
        // Generate output filename with timestamp and status
        Set outputFileName = ##class(Demo.Util.Logger).GenerateOutputFileName(fileName, status)
        Set outputPath = ..OutputDir _ "/" _ outputFileName
        
        // Ensure output directory exists
        If '##class(%File).DirectoryExists(..OutputDir) {
            Do ##class(%File).CreateDirectoryChain(..OutputDir)
        }
        
        // Move/copy file
        If ##class(%File).Exists(filePath) {
            Set result = ##class(%File).CopyFile(filePath, outputPath)
            If result {
                // Delete original file after successful copy
                Set result = ##class(%File).Delete(filePath)
                If result {
                    Do ##class(Demo.Util.Logger).WriteFileLog("MOVED " _ fileName _ " to " _ outputFileName)
                } Else {
                    Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.FileService", "File copied but failed to delete original: " _ filePath)
                }
            } Else {
                Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.FileService", "Failed to copy file to output: " _ filePath)
                Set result = $$$ERROR(5001, "Failed to copy file to output directory")
            }
        } Else {
            Do ##class(Demo.Util.Logger).WriteEvent("WARNING", "Demo.FileService", "Source file no longer exists: " _ filePath)
        }
        
    } Catch ex {
        Set result = ex.AsStatus()
        Do ##class(Demo.Util.Logger).WriteEvent("ERROR", "Demo.FileService", "Error moving file " _ fileName _ ": " _ ex.DisplayString())
    }
    
    Return result
}

/// Get service statistics for monitoring
Method GetStats() As %String
{
    Set stats = ""
    
    Try {
        Set stats = stats _ "Service: Demo.FileService" _ $C(13,10)
        Set stats = stats _ "Input Dir: " _ ..InputDir _ $C(13,10)
        Set stats = stats _ "Output Dir: " _ ..OutputDir _ $C(13,10)
        Set stats = stats _ "Log Dir: " _ ..LogDir _ $C(13,10)
        Set stats = stats _ "Target: " _ ..TargetConfigName _ $C(13,10)
        Set stats = stats _ "Status: " _ ..%GetParameter("ADAPTER") _ $C(13,10)
        
    } Catch ex {
        Set stats = "Error getting stats: " _ ex.DisplayString()
    }
    
    Return stats
}

}