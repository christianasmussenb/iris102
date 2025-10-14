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
        Set fileSize = ##class(Demo.Util.Logger).GetFileSize(filePath)
        
        Do ##class(Demo.Util.Logger).WriteEvent("INFO", "Demo.FileService", "Processing file: " _ fileName _ " (" _ fileSize _ " bytes)")
        Do ##class(Demo.Util.Logger).WriteFileLog("START " _ fileName _ " size=" _ fileSize _ " path=" _ filePath)
        
        // Validate CSV file format
        Set valid = ##class(Demo.Util.Logger).ValidateCSVFile(filePath, .errorMsg)
        If 'valid {
            Do ..HandleFileError(fileName, filePath, "invalid", "CSV validation failed: " _ errorMsg)
            Return $$$OK
        }
        
        // Calculate file hash for duplicate detection
        Set fileHash = ##class(Demo.Util.Logger).HashFile(filePath)
        If fileHash = "" {
            Do ..HandleFileError(fileName, filePath, "error", "Failed to calculate file hash")
            Return $$$OK
        }
        
        Do ##class(Demo.Util.Logger).WriteFileLog("HASH " _ fileName _ " hash=" _ fileHash)
        
        // Check for duplicates
        If ##class(Demo.Util.Logger).IsDuplicateFile(filePath, fileHash) {
            Do ..HandleFileError(fileName, filePath, "duplicate", "File is a duplicate (hash: " _ fileHash _ ")")
            Return $$$OK
        }
        
        // Mark file as being processed
        Do ##class(Demo.Util.Logger).MarkFileAsProcessed(fileName, fileHash, "processing")
        
        // Create request message for Business Process
        Set request = ##class(Demo.Msg.FileProcessRequest).%New()
        Set request.FilePath = filePath
        Set request.FileName = fileName
        Set request.FileSize = fileSize
        Set request.FileHash = fileHash
        Set request.DetectedAt = ##class(Demo.Util.Logger).NowISO()
        Set request.RetryCount = 0
        
        // Send to Business Process
        Set status = ..SendRequestSync(..TargetConfigName, request, .response, 300) // 5 minute timeout
        
        If $$$ISERR(status) {
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