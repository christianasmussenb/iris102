Class iris.src.demo.bo.MySQLInsert Extends %RegisteredObject
{

Parameter ADAPTER = "EnsLib.SQL.OutboundAdapter";
Property Adapter As EnsLib.SQL.OutboundAdapter;

/// DSN del SQL Gateway
Parameter DSN = "MySQL-Demo-JDBC";

Method OnInit() As %Status
{
    Set ..Adapter.DSN = ..#DSN
    Quit $$$OK
}

Method OnMessage(pReq As DEMO.msg.ImportRow, Output pResp As Ens.Response) As %Status
{
    Set tSC = $$$OK, pResp = ##class(Ens.Response).%New()
    Set sql = "INSERT INTO sales_import (source_file,row_num,order_id,customer_id,amount,currency,order_date,idem_key) VALUES (?,?,?,?,?,?,?,?)"
    Try {
        Do ..Adapter.Prepare(.stmt, sql)
        Do stmt.%Execute(pReq.SourceFile, pReq.RowNum, pReq.OrderId, pReq.CustomerId, pReq.Amount, pReq.Currency, pReq.OrderDate, pReq.IdemKey)
        Do ..Adapter.Commit()
    } Catch ex {
        If $Find($ZCVT(ex.DisplayString(),"L"),"unique") {
            Set tSC = $$$OK
        } Else {
            Set tSC = ex.AsStatus()
        }
    }
    Quit tSC
}
}
