Class iris.src.demo.dtl.CSVtoRow Extends %RegisteredObject
{

XData DTL
{
<transform sourceClass="EnsLib.RecordMap.Record" targetClass="DEMO.msg.ImportRow">
  <assign value="source.GetFieldByName(&quot;order_id&quot;)" property="target.OrderId"/>
  <assign value="source.GetFieldByName(&quot;customer_id&quot;)" property="target.CustomerId"/>
  <assign value="source.GetFieldByName(&quot;amount&quot;)" property="target.Amount"/>
  <assign value="source.GetFieldByName(&quot;currency&quot;)" property="target.Currency"/>
  <assign value="source.GetFieldByName(&quot;order_date&quot;)" property="target.OrderDate"/>
  <assign value="context.Source" property="target.SourceFile"/>
  <assign value="context.CurrentRecord" property="target.RowNum"/>
  <assign value="$SYSTEM.Encryption.SHAHash(&quot;SHA256&quot;,target.SourceFile_&quot;#&quot;_target.RowNum_&quot;#&quot;_target.OrderId)" property="target.IdemKey"/>
</transform>
}
}
