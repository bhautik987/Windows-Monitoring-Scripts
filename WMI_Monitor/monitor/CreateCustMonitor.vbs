args = WScript.Arguments(0)

Dim objFSO
Set objFSO = CreateObject("Scripting.FileSystemObject")
Const ForReading = 1
strLine = ""
dim tag,name, FullresultParams,objxmlDoc,objName,objTag,rootfolder,Root,NodeList,nodeVal,res,objtype,monitorType,filesysObj,isSelect,portal
rootfolder = left(WScript.ScriptFullName,(Len(WScript.ScriptFullName))-(len(WScript.ScriptName)))
dim instanceName
dim duration
set objxmlDoc = CreateObject("Microsoft.XMLDOM")
objxmlDoc.async="false"

'Your API key and Secret Key from XML
set xmlDoc=CreateObject("Microsoft.XMLDOM")
xmlDoc.async="false"
xmlDoc.load(args)
apiKey = xmlDoc.GetElementsByTagName("ApiKey").item(0).text
secretKey = xmlDoc.GetElementsByTagName("SecretKey").item(0).text
connectTo = xmlDoc.GetElementsByTagName("ConnectTo").item(0).text

if connectTo = "Monitis" then
	portal = "api.monitis.com"
elseif connectTo = "Monitor.us" then
	portal = "www.monitor.us"
end if
'Finds current timezone to obtain GMT date 
dtGMT = GMTDate()
unixDate = CStr(DateDiff("s", "01/01/1970 00:00:00", DateSerial(Year(dtGMT), Month(dtGMT), Day(dtGMT)) + TimeSerial(Hour(dtGMT), Minute(dtGMT), Second(dtGMT)))) + "000"
'Initialize HTTP connection object
Set objHTTP = CreateObject("Microsoft.XMLHTTP")
'Request a token to use in following calls
url = "http://" + portal + "/api?action=authToken&apikey=" + apiKey + "&secretkey=" + secretKey
objHTTP.open "GET", url, False
objHTTP.send
resp = objHTTP.responseText
token = DissectStr(resp, "authToken"":""", """")

Set Root = xmlDoc.documentElement 
Set NodeList = Root.selectsingleNode("/Monitor")  
'Add new monitor in Monitis server and push data
For Each Elem In NodeList.childnodes 
	nodeVal = Elem.nodename
	set instanceName = xmlDoc.documentElement.selectSingleNode("//" & nodeVal & "/InstanceName")
	set monitorID = xmlDoc.documentElement.selectSingleNode("//" & nodeVal & "/monitorID")
	'Get Tag,name and host name form XML
	set objName = xmlDoc.documentElement.selectSingleNode("//"& nodeVal & "/properties/Name")
	name = objName.text

	set objTag = xmlDoc.documentElement.selectSingleNode("//" & nodeVal & "/properties/Monitor_Group")
	tag = objTag.text
	
	set objHost = xmlDoc.documentElement.selectSingleNode("//" & nodeVal & "/properties/HostName")
	computer = objHost.text  
	
	set objtype = xmlDoc.documentElement.selectSingleNode("//" & nodeVal & "/properties/Type")
	monitorType = objtype.text 
	preValueFile = xmlDoc.documentElement.selectSingleNode("//" & nodeVal & "/filepath").Text
	
'-------------------------------------------------------------------------------------------------------
	on error resume next
	Set oWMI = GetObject("WINMGMTS:\\" & computer & "\ROOT\cimv2")
	if  Err.Number <> 0  then
		computer = MsgBox("WMI connection faild")
		Err.Clear
	else
		dim sos   
		Dim preValues 
		preValues = Now & chr(13)
		Dim preValuesInDictionary 
		Set preValuesInDictionary = CreateObject("Scripting.Dictionary")
		if preValueFile <> "" then
			'Finding checked metrics from XML document
			Set objFile = objFSO.OpenTextFile(rootfolder & preValueFile, ForReading)
			Do Until objFile.AtEndOfStream
				strLine =  objFile.ReadLine
			Loop
			str = Left(Replace(strLine,chr(13),","),len(Replace(strLine,chr(13),","))-1)
			sos = split(str,",")
			for i = 0 to UBound(sos)
				k = i mod 2
				if k <> 0 then 
					preValuesInDictionary.Add sos(i),sos(i+1)
				end if
			next
		else
			for j = 0 to (metName.Length)-1 
				if metName.item(j).text = "true" and metName.item(j).getAttribute("isdinamic") <> "standart" then
					preValuesInDictionary.add metName.item(j).getAttribute("methodName"),0
				end if
			next
		end if
		duration  = sos(0)
		interval = DateDiff("s",duration , Now )
		'if Monitor ID doesn't exeists create new monitor and push data
		
		if monitorID.text = 0 Then
			MsgBox "Creating new " + nodeVal + " monitor..."
			
			AddCustMon
			
			'Requests the monitor list so we can find the MonitorID of each printer monitor on the dashboard page
			url = "http://"+portal+"/customMonitorApi?action=getMonitors&apikey=" + apiKey + "&tag=" + tag + "&output=xml"
			objHTTP.open "GET", url, False
			objHTTP.send
			resp = objHTTP.responseText
			Set objResponse = CreateObject("Microsoft.XMLDOM")
			objResponse.async = False
			objResponse.LoadXML(resp)
			res = GetNetworkData
			monitorID.text = FindMonitorID(name)
			xmlDoc.save(args)
			AddResult
			if connectTo = "Monitis" then
				AddPage
			end if
			'if monitor ID exeists only push data
			elseif monitorID.text <> 0 then 
			res = GetNetworkData
			AddResult
		end if
	end if
	xmlDoc.load(args)
Next

'---------------------------------------------------------------------
'Add Page to user's dash board
Function AddPage
	Set obj_HTTP = CreateObject("Microsoft.XMLHTTP")
	objxmlDoc.load(args)
	Set NodeList = objxmlDoc.documentElement.Selectsinglenode("/Monitor").childnodes 
	for each node in nodelist
		app = node.nodename 
		set TagNode = objxmlDoc.documentElement.Selectsinglenode(app&"/DashboardTag")
		title = TagNode.text
	next
	set attributes = objxmlDoc.documentElement.GetelementsbytagName(app&"/DashboardTag")
	for each attr in attributes
		ID = attr.getattribute("ID")
		isExists = attr.getattribute("exists")
	next
	if isexists = "false" and title<>"" then
		url = "http://api.monitis.com/api"
		objHTTP.open "POST", url, False
		objHTTP.setRequestHeader "Content-Type", "application/x-www-form-urlencoded"
		postData = "apikey="+apiKey+"&validation=token&authToken="+ token +"&timestamp="+ FmtDate(dtGMT)+"&version=2&action=addPage&title="+title
		objHTTP.send postData
		resp = objHTTP.responseText
		nstart = instr(resp,"pageId")
		nstart = nstart+len("pageId""""")
		nEnd = InStr(nstart,resp,"2")
		pageID =  mid(resp, nStart,len(resp) - nstart-1)
		objxmlDoc.Save(args)
		objxmlDoc.load(args)
		set attributes1 = objxmlDoc.documentElement.GetelementsbytagName(app&"/DashboardTag")
		for each attr in attributes1
			attr.setattribute "exists","true"
			attr.setattribute "ID",pageID
		next
		objxmlDoc.save(args)
		AddModule_postData = "apikey="+ apiKey+"&validation=token&authToken=" + token+"&timestamp="+FmtDate(dtGMT)+"&version=2&action=addPageModule&moduleName=CustomMonitor&pageId="+pageID+"&column=1&row=2&dataModuleId="+monitorID.text+"&height=400"
	elseIF isexists = "true" then
		AddModule_postData = "apikey="+ apiKey+"&validation=token&authToken=" + token+"&timestamp="+FmtDate(dtGMT)+"&version=2&action=addPageModule&moduleName=CustomMonitor&pageId="+ID+"&column=1&row=2&dataModuleId="+monitorID.text+"&height=400"
	end if
	url1 = "http://api.monitis.com/api"
	obj_HTTP.open "POST", url1, False
	obj_HTTP.setRequestHeader "Content-Type", "application/x-www-form-urlencoded"
	obj_HTTP.send AddModule_postData
	resp1 = obj_HTTP.responseText
end Function


'Create custom monitor in dashboard
Function AddCustMon

	FullresultParams = ""
	objxmlDoc.load(args)
    dim j,objChild,root,node
    set classnodes = objxmlDoc.documentElement.selectNodes("//" & nodeVal &"/metrics/metric")
     for i = 0 to (classnodes.length)-1
		if classnodes.item(i).text = "true" then
			FullresultParams = FullresultParams + classnodes.item(i).getAttribute("resultParams")
        end if
    next
    url = "http://"+portal+"/customMonitorApi"
    objHTTP.open "POST", url, False
    objHTTP.setRequestHeader "Content-Type", "application/x-www-form-urlencoded"
    postData = "apikey=" + apiKey + "&validation=token&authToken=" + token + "&timestamp=" + FmtDate(dtGMT) + "&action=addMonitor&resultParams=" + FullresultParams + "&name=" + name + "&tag=" + tag + "&type=" + monitorType
	objHTTP.send postData
    resp = objHTTP.responseText
End Function

'Create results for pushing data
Function GetNetworkData
objxmlDoc.load(args)
	dim node
	node = "//"& nodeVal &"/metrics/metric"
	
	
	set metName = objxmlDoc.documentElement.selectNodes(node)
	
	fullResult = ""
	dim s   
	for j = 0 to (metName.Length)-1 
		value = 0
		curValue = 0
		s = Left(metName.item(j).getAttribute("resultParams"),InStr(metName.item(j).getAttribute("resultParams"), ":")) 
		
		if metName.item(j).text = "true" then
			instance = metName.item(j).getAttribute("instance")
			if instance = "true" then
				Set oRes = oWMI.ExecQuery ("select * from " & metName.item(j).getAttribute("WMIclass")  & " where Name= "& chr(34) & instanceName.text & chr(34))
			else
				Set oRes = oWMI.ExecQuery ("select * from " & metName.item(j).getAttribute("WMIclass"))
			end if	
			'Enumerate instances
			For each oEntry in oRes
				if metName.item(j).getAttribute("isdinamic") = "Per time Unit" then
					on error resume next
					'Get metrics' values
					curValue = oEntry.Properties_(metName.item(j).getAttribute("methodName"))
					
					Value = (curValue - preValuesInDictionary.Item(metName.item(j).getAttribute("methodName")) ) / interval
					if  Err.Number <> 0  then   
						ValueExists  = ValueExists +"  " + metName.item(j).getAttribute("methodName") 
						Value = ""
						nullCount = nullCount + 1
						Err.Clear
					end if
				elseif metName.item(j).getAttribute("isdinamic") = "Raw Value" then
					on error resume next 
					value = oEntry.Properties_(metName.item(j).getAttribute("methodName"))
					curValue = value
					if  Err.Number <> 0  then   
						ValueExists  = ValueExists +"  " + metName.item(j).getAttribute("methodName") 
						Value = ""
						nullCount = nullCount + 1
						Err.Clear
					end if
				elseif metName.item(j).getAttribute("isdinamic") = "Difference" then
					on error resume next
					'Get metrics' values
					curValue = oEntry.Properties_(metName.item(j).getAttribute("methodName"))
					Value = (curValue - preValuesInDictionary.Item(metName.item(j).getAttribute("methodName")))
					if  Err.Number <> 0  then   
						ValueExists  = ValueExists +"  " + metName.item(j).getAttribute("methodName") 
						Value = ""
						nullCount = nullCount + 1
						Err.Clear
					end if
				elseif metName.item(j).getAttribute("isdinamic") = "Percent" then
					on error resume next
					'Get metrics' values
					curValue = oEntry.Properties_(metName.item(j).getAttribute("methodName"))
					Value = ((curValue - preValuesInDictionary.Item(metName.item(j).getAttribute("methodName")))/(interval*100000))
					if  Err.Number <> 0  then   
						ValueExists  = ValueExists +"  " + metName.item(j).getAttribute("methodName") 
						Value = ""
						nullCount = nullCount + 1
						Err.Clear
					end if
				end if
			next
			results = s & Round(CDbl(Value),2) & ";"
			fullResult =  fullResult & results
			'results = results +  s & space(30 - len(s)) & chr(9) & Abs(Value) & chr(13)
			preValuesInFile = preValuesInFile + metName.item(j).getAttribute("methodName") & "," & curValue & chr(13)
		end if
	next
	 ' Output result
	 if ValueExists = "" then
		 MsgBox results,,nodeVal.nodename & "Test result"
	 end if
	 if  nullCount = checkedCnt and checkedcount<>0 then
		 MsgBox results & chr(13) & "Make sure that monitored application is avaliable in your computer",,nodeVal.nodename & "Test result"
	 elseif nullCount <> 0 then 
		 MsgBox  results & chr(13) & "Values of  " &  ValueExists & "  don't exist",,nodeVal.nodename & "Test result"
	 end if
	if objFSO.FileExists(rootfolder & preValueFile ) Then
		fileName = preValueFile
		Set objFile1 = objFSO.CreateTextFile(rootfolder & fileName , 2)
		objFile1.Write preValues  & preValuesInFile
	else
		fileName = "preValues"&token&".csv"
		xmlDoc.documentElement.selectSingleNode("//" & nodeVal & "/filepath").Text = filename
		Set newFile = objFSO.CreateTextFile(rootfolder & fileName)
		xmlDoc.Save(args)
		newFile.Write preValues  & preValuesInFile
	end if
	GetNetworkData =  fullResult
End Function


'add results in dashboard
Sub AddResult

  url = "http://"+portal+"/customMonitorApi"
  action = "addResult"
  objHTTP.open "POST", url, False
  objHTTP.setRequestHeader "Content-Type", "application/x-www-form-urlencoded"
  postData = "apikey=" + apiKey + "&validation=token&authToken=" + token + "&timestamp=" + FmtDate(dtGMT) + "&action=" + action + "&monitorId=" + monitorID.Text + "&checktime=" + UnixDate + "&results=" + res
  objHTTP.send postData
  resp = objHTTP.responseText
End Sub

'find monitor ID from XML
Function FindMonitorID(monName)
  For Each objNode in objResponse.documentElement.childnodes
    If objNode.selectSingleNode("name").text = monName Then
      FindMonitorID = objNode.selectSingleNode("id").text
	  Exit For
    End If
  Next
End Function

'------------------------------------------------------------------
Function DissectStr(cString, cStart, cEnd)
'Generic string manipulation function to extract value from JSON output
  dim nStart, nEnd
  nStart = InStr(cString, cStart)
  if nStart = 0 then 
    DissectStr = ""
  else
    nStart = nStart + len(cStart)
    if cEnd = "" then
      nEnd = len(cString)
    else
      nEnd = InStr(nStart, cString, cEnd)
      if nEnd = 0 then nEnd = nStart else nEnd = nEnd - nStart
    end if
    DissectStr = mid(cString, nStart, nEnd)
  end if
End Function

'---------------------------------------------------------------------
'Set date and time
Function FmtDate(dt)
  FmtDate = cstr(Datepart("yyyy", dt)) + "-" + right("0" + cstr(Datepart("m", dt)),2) + "-" +  right("0" + cstr(Datepart ("d", dt)),2) + " " + right("0" + cstr(Datepart("h", dt)),2) + ":" + right("0" + cstr(Datepart("n", dt)),2) + ":" + right("0" + cstr(Datepart("S", dt)),2)
end function
'---------------------------------------------------------------------
'Get date and time from WMI
Function GMTDate() 
  dim oWMI, oRes, oEntry
  Set oWMI = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
  GMTDate = now
  Set oRes = oWMI.ExecQuery("Select LocalDateTime from Win32_OperatingSystem")
  For each oEntry in oRes
    GMTDate = DateAdd("n", -CInt(right(oEntry.LocalDateTime, 4)), GMTDate)
  next
End function