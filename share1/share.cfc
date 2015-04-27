<!---http://sharecfc.riaforge.org/--->
<!---Raymond Camdeon --->


<cfcomponent displayName="Adobe Share Wrapper" output="false">

<cfset variables.username = "">
<cfset variables.password = "">
<cfset variables.apikey = "">
<cfset variables.sharedsecret = "">
<cfset variables.authtoken = "">
<cfset variables.sessionid = "">

<cffunction name="init" access="public" returnType="AcrobatCom" output="false">
	<cfargument name="username" type="string" required="true">
	<cfargument name="password" type="string" required="true">
	<cfargument name="apikey" type="string" required="true">
	<cfargument name="sharedsecret" type="string" required="true">

	<cfset variables.username = arguments.username>
	<cfset variables.password = arguments.password>
	<cfset variables.apikey = arguments.apikey>
	<cfset variables.sharedsecret = arguments.sharedsecret>

	<!--- now authenticate --->
	<cfset authenticate()>
	<!--- and start a session --->
	<cfset startSession()>

	<cfreturn this>
</cffunction>

<cffunction name="arrayToXML" returnType="string" access="public" output="false" hint="Converts an array into XML">
	<cfargument name="data" type="array" required="true">
	<cfargument name="itemelement" type="string" required="true">
	<cfargument name="doroot" type="boolean" required="false" default="true">
	<cfset var s = createObject('java','java.lang.StringBuffer').init()>
	<cfset var x = "">

	<cfif arguments.doroot>
		<cfset s.append("<?xml version=""1.0"" encoding=""UTF-8""?>")>
	</cfif>

	<cfloop index="x" from="1" to="#arrayLen(arguments.data)#">
		<cfset s.append("<#arguments.itemelement#>#xmlFormat(arguments.data[x])#</#arguments.itemelement#>")>
	</cfloop>

	<cfreturn s.toString()>
</cffunction>

<cffunction name="authenticate" access="public" returnType="void" output="false">
	<cfset var response = "">
	<cfset var authxml = "">
	<cfset var auth = {username=variables.username,password=variables.password}>

	<cfset response = shareHit("POST https://api.acrobat.com/webservices/api/v1/auth/",auth)>
    
	<cfif response is "BadLogin">
		<cfthrow message="Invalid Login">
	</cfif>
    
    <cfif response is "Connection Failure">
		<cfthrow message="Connection Failure">
	</cfif>

	<cfif response is "NoTOU">
		<cfthrow message="No Terms of Use: Adobe has changed the Terms of Use and has shut down the API until you manually log back into the acrobat.com website and accept the updated TOU.">
	</cfif>

    	<cfset response = xmlParse(trim(response))>

		<cfif response.response.xmlAttributes.status is not "ok">
            <cfdump var="#response#" label="error">
        <cfelse>
            <cfset variables.authtoken = response.response.authtoken.xmltext>
        </cfif>

</cffunction>

<cffunction name="delete" access="public" returnType="void" output="false" hint="Deletes a file or folder.">
	<cfargument name="node" type="string" required="true">
	<cfset var myurl = "DELETE https://api.acrobat.com/webservices/api/v1/dc/" & arguments.node & "/">
	<cfset var result = shareHit(myurl)>

	<cfif result is "Error">
		<cfthrow message="Share Error">
	</cfif>

</cffunction>

<cffunction name="download" access="public" returnType="void" output="false" hint="Downloads a file.">
	<cfargument name="node" type="string" required="true">
	<cfargument name="filename" type="string" required="true"> 

	<cfset var myurl = "GET https://api.acrobat.com/webservices/api/v1/dc/#arguments.node#/src/">
	<cfset var response = shareHit(action=myurl,binary="yes")>
	<cffile action="write" file="#arguments.filename#" output="#response#">

</cffunction>

<cffunction name="downloadThumbnail" access="public" returnType="void" output="false" hint="Downloads a thumbnail. This is a JPG (afaik).">
	<cfargument name="node" type="string" required="true">
	<cfargument name="filename" type="string" required="true">

	<cfset var myurl = "GET https://api.acrobat.com/webservices/api/v1/dc/#arguments.node#/thumbnail/">
	<cfset var response = shareHit(action=myurl,binary="yes")>
	<cffile action="write" file="#arguments.filename#" output="#response#">

</cffunction>

<cffunction name="epochTimeToDate" access="private" returnType="date" output="false">
	<cfargument name="epoch" type="numeric" required="true">
	<cfreturn dateAdd("s", epoch, "January 1 1970 00:00:00")>
</cffunction>

<cffunction name="generateAuthHeader" access="private" returnType="string" output="false" hint="I generate the header string for authorization.">
	<cfargument name="action" type="string" required="true">
	<cfset var str = "">
	<cfset var md = arguments.action & " " & getTickCount()>

	<cfsavecontent variable="str">
	<cfoutput>AdobeAuth apikey="#variables.apikey#",<cfif len(variables.sessionid)>sessionid="#variables.sessionid#",</cfif>data="#md#",sig="#lcase(hash("#md##variables.sharedsecret#"))#"</cfoutput>
	</cfsavecontent>

	<cfreturn trim(str)>
</cffunction>

<cffunction name="list" access="public" returnType="query" output="false" hint="Return a query of files.">
	<cfargument name="node" type="string" required="false">
	<cfset var response = "">
	<cfset var myurl = "GET https://api.acrobat.com/webservices/api/v1/dc/">
	<cfset var result = queryNew("createddate,description,directory,hascontent,link,modifieddate,name,nodeid,owner,ownername,adobedoc,author,filesize,flashpreviewembed,flashpreviewpagecount,flashpreviewstate,mimetype,recipients,recipienturl,sharelevel,thumbnailstate")>
	<cfset var x = "">
	<cfset var cnode = "">
	<cfset var col = "">

	<cfif structKeyExists(arguments, "node")>
		<cfset myurl = myurl & arguments.node & "/">
	</cfif>

	<cfset response = shareHit(myurl)>

	<cfset response = xmlParse(trim(response))>

	<cfif response.response.xmlAttributes.status is not "ok">
		<cfdump var="#response#" label="error">
	<cfelse>
		<cfloop index="x" from="1" to="#arrayLen(response.response.children.node)#">
			<cfset cnode = response.response.children.node[x]>
			<cfset queryAddRow(result)>
			<!--- do simple gets first --->
			<cfloop index="col" list="#result.columnlist#">
				<cfif structKeyExists(cnode.xmlAttributes, col)>
					<cfset querySetCell(result,"#col#",cnode.xmlAttributes[col])>
				</cfif>
			</cfloop>
			<!--- now do dates --->
			<cfset querySetCell(result, "createddate", epochTimeToDate(cnode.xmlAttributes["createddate"]/1000))>
			<cfset querySetCell(result, "modifieddate", epochTimeToDate(cnode.xmlAttributes["modifieddate"]/1000))>

			<!---
			change share: from docs, if 0, unshared, if 1, shared, if 2, public
			--->
			<cfif structKeyExists(cnode.xmlAttributes, "sharelevel")>
				<cfif cnode.xmlAttributes.sharelevel is 0>
					<cfset querySetCell(result, "sharelevel", "unshared")>
				<cfelseif cnode.xmlAttributes.sharelevel is 1>
					<cfset querySetCell(result, "sharelevel", "shared")>
				<cfelse>
					<cfset querySetCell(result, "sharelevel", "public")>
				</cfif>
			</cfif>
		</cfloop>
	</cfif>
	<cfreturn result>
</cffunction>

<cffunction name="move" access="public" returnType="void" output="false" hint="Renames a file or folder.">
	<cfargument name="node" type="string" required="true">
	<cfargument name="destination" type="string" required="true">
	<cfargument name="newname" type="string" required="false" default="">

	<cfset var myurl = "POST https://api.acrobat.com/webservices/api/v1/dc/" & arguments.node & "/?method=move&destnodeid=#urlEncodedFormat(arguments.destination)#">
	<cfset var realurl = "MOVE https://api.acrobat.com/webservices/api/v1/dc/" & arguments.node & "/?destnodeid=#urlEncodedFormat(arguments.destination)#">
	<cfset var result = "">
	<cfset var response = "">

	<cfif len(arguments.newname)>
		<cfset myurl = myurl & "&newname=#urlEncodedFormat(arguments.newname)#">
		<cfset realurl = realurl & "&newname=#urlEncodedFormat(arguments.newname)#">
	</cfif>

	<cfset result = shareHit(action=myurl,realurl=realurl)>

	<cfif result is "Error">
		<cfthrow message="Share Error">
	</cfif>

	<cfset response = xmlParse(trim(result))>

	<cfif response.response.xmlAttributes.status is not "ok">
		<cfdump var="#response#" label="error">
	</cfif>

</cffunction>

<cffunction name="newfolder" access="public" returnType="struct" output="false" hint="Adds a folder.">
	<cfargument name="name" type="string" required="true">
	<cfargument name="description" type="string" required="false">
	<cfargument name="node" type="string" required="false" default="">
	<cfset var s = structNew()>
	<cfset var myurl = "POST https://api.acrobat.com/webservices/api/v1/dc/">
	<cfset var response = "">

	<cfif structKeyExists(arguments, "node")>
		<cfset myurl= myurl & arguments.node & "/">
	</cfif>

	<cfset s.folder = structNew()>
	<cfset s.folder.name = arguments.name>

	<cfif structKeyExists(arguments, "description")>
		<cfset s.folder.description = arguments.description>
	</cfif>

	<cfset response = shareHit(myurl,s)>

	<cfif response is "Error">
		<cfthrow message="Share Error">
	</cfif>

	<!--- Response should be just the new node. --->
	<cfset response = xmlParse(trim(response))>
	<cfif response.response.xmlAttributes.status is "ok">
		<cfreturn nodeToStruct(response.response.node)>
	<cfelse>
		<!--- This shouldn't happen. --->
		<cfthrow message="Share Error - Unknown">
	</cfif>

</cffunction>

<cffunction name="nodeToStruct" access="private" returnType="struct" output="false" hint="Converts Node XML to struct">
	<cfargument name="node" type="XML" required="true">
	<cfset var s = structNew()>
	<cfset var c = "">

	<cfloop item="c" collection="#arguments.node.xmlAttributes#">
		<cfset s[c] = arguments.node.xmlAttributes[c]>
	</cfloop>

	<!--- fix the dates --->
	<cfset s.createddate = epochTimeToDate(s.createddate/1000)>
	<cfset s.modifieddate = epochTimeToDate(s.modifieddate/1000)>

	<cfreturn s>
</cffunction>

<cffunction name="rename" access="public" returnType="void" output="false" hint="Renames a file or folder.">
	<cfargument name="node" type="string" required="true">
	<cfargument name="newname" type="string" required="true">

	<cfset var myurl = "POST https://api.acrobat.com/webservices/api/v1/dc/" & arguments.node & "/?method=move&newname=#urlEncodedFormat(arguments.newname)#">
	<cfset var realurl = "MOVE https://api.acrobat.com/webservices/api/v1/dc/" & arguments.node & "/?newname=#urlEncodedFormat(arguments.newname)#">
	<cfset var result = shareHit(action=myurl,realurl=realurl)>

	<cfif result is "Error">
		<cfthrow message="Share Error">
	</cfif>
</cffunction>

<cffunction name="share" access="public" returnType="void" output="false" hint="Shares a document with others.">
	<cfargument name="node" type="string" required="true">
	<cfargument name="emaillist" type="string" required="true">
	<cfargument name="message" type="string" required="true">
	<cfargument name="level" type="string" required="true" hint="private or public">

	<cfset var myurl = "PUT https://api.acrobat.com/webservices/api/v1/dc/#arguments.node#/share/">
	<cfset var s = structNew()>
	<cfset var x = "">
	<cfset var r = "">

	<cfset s.share.user = arrayNew(1)>
	<cfloop index="x" from="1" to="#listLen(arguments.emaillist)#">
		<cfset arrayAppend(s.share.user, listGetAt(arguments.emaillist, x))>
	</cfloop>
	<cfset s.message = arguments.message>

	<cfif arguments.level is "private">
		<cfset s.level = 1>
	<cfelseif arguments.level is "public">
		<cfset s.level = 2>
	<cfelse>
		<cfthrow message="Share Invalid level value. Must be private or public.">
	</cfif>

	<cfset r = shareHit(action=myurl,data=s,order="share,message,level")>

	<cfif r is "Error">
		<cfthrow message="Share Error">
	</cfif>

</cffunction>

<cffunction name="shareHit" access="private" returnType="any" output="false" hint="I perform REST hits for the rest of the CFC.">
	<cfargument name="action" type="string" required="true">
	<cfargument name="data" type="any" required="false">
	<cfargument name="debug" type="boolean" required="false" default="false">
	<cfargument name="file" type="string" required="false">
	<cfargument name="binary" type="string" default="no">
	<cfargument name="order" type="string" default="">
	<cfargument name="realurl" type="string" default="">

	<!--- get my auth header --->
	<cfset var authheader = "">
	<cfset var result = "">
	<cfset var myurl = listRest(arguments.action, " ")>
	<cfset var xml = "">
	<cfset var method = listFirst(arguments.action, " ")>
	<!--- authheader is based on action, unless we are POST tunneling, in which case we pass real url --->
	<cfif len(arguments.realurl)>
		<cfset authheader = generateAuthHeader(arguments.realurl)>
	<cfelse>
		<cfset authheader = generateAuthHeader(arguments.action)>
	</cfif>

	<cfif structKeyExists(arguments, "data")>
		<cfset xml = structToXML(doRoot=false,data=arguments.data, rootElement="request", order=arguments.order)>
		<cfif not isXml(xml)>
			<cfthrow message="Invalid XML returned from structToXML">
		</cfif>
	</cfif>
	<cfif arguments.debug>
		<cfdump var="#xml#">
		<cfabort>
	</cfif>


	<!--- now hit it baby! --->
	<cfif structKeyExists(arguments, "files")>
		<cfset mp = true>
	<cfelse>
		<cfset mp = false>
	</cfif>
 
    
	<cfhttp url="#myurl#" method="#method#" result="result" getasbinary="#arguments.binary#" multipart="#mp#" charset="utf-8">  <!--- added charset="utf-8" --->
		<cfhttpparam type="header" name="Authorization" value="#authheader#">

		<cfif structKeyExists(arguments,"file")>
			<cfhttpparam type="file" name="file" file="#trim(arguments.file)#" > 
		</cfif>

		<cfif len(xml)>
			<cfif listFindNoCase("post,get",method)>
				<cfif structKeyExists(arguments, "file")>
					<cfhttpparam type="formField" name="request" value="#trim(xml)#" encoded="false">
				<cfelse>
					<cfhttpparam type="body" name="request" value="#trim(xml)#" encoded="false">
				</cfif>
			<cfelseif method is "put">
				<cfhttpparam type="body" value="#xml#">
			</cfif>
		</cfif>

	</cfhttp>

	<cfreturn result.fileContent>

</cffunction>

<cffunction name="shareUpdate" access="public" returnType="void" output="false" hint="Updates an already shared document.">
	<cfargument name="node" type="string" required="true">
	<cfargument name="addlist" type="string" required="false" default="">
	<cfargument name="removelist" type="string" required="false" default="">
	<cfargument name="message" type="string" required="true">

	<cfset var myurl = "POST https://api.acrobat.com/webservices/api/v1/dc/#arguments.node#/share/">
	<cfset var s = structNew()>
	<cfset var x = "">
	<cfset var r = "">

	<cfset s.share.user = arrayNew(1)>
	<cfset s.unshare.user = arrayNew(1)>

	<cfif len(arguments.addlist)>
		<cfloop index="x" from="1" to="#listLen(arguments.addlist)#">
			<cfset arrayAppend(s.share.user, listGetAt(arguments.addlist, x))>
		</cfloop>
	</cfif>

	<cfif len(arguments.removelist)>
		<cfloop index="x" from="1" to="#listLen(arguments.removelist)#">
			<cfset arrayAppend(s.unshare.user, listGetAt(arguments.removelist, x))>
		</cfloop>
	</cfif>

	<cfset s.message = arguments.message>

	<cfset r = shareHit(action=myurl,data=s,order="share,unshare,message",debug=1)>

	<cfif r is "Error">
		<cfthrow message="Share Error">
	</cfif>

</cffunction> 

<cffunction name="startSession" access="public" returnType="void" output="false" hint="I start a new session.">
	<cfset var authxml = "">
	<cfset var data = {authtoken=variables.authtoken}>

	<cfset response = shareHit("POST https://api.acrobat.com/webservices/api/v1/sessions/",data)>

	<cfset response = xmlParse(trim(response))>

	<cfif response.response.xmlAttributes.status is not "ok">
		<cfdump var="#response#" label="error">
	<cfelse>
		<cfset variables.sessionid = response.response.sessionid.xmltext>
		<!--- shared secret changes --->
		<cfset variables.sharedsecret = response.response.secret.xmltext>
		<cfset variables.name = response.response.name.xmltext>
		<cfset variables.level = response.response.level.xmltext>
	</cfif>

</cffunction>

<cffunction name="structToXML" returnType="string" access="public" output="false" hint="Converts a struct into XML.">
	<cfargument name="data" type="struct" required="true">
	<cfargument name="rootelement" type="string" required="true">
	<cfargument name="doroot" type="boolean" required="false" default="true">
	<cfargument name="order" type="string" required="false" default="">
	<cfset var s = createObject('java','java.lang.StringBuffer').init()>
	<cfset var keys = "">
	<cfset var key = "">

	<cfif arguments.order neq "">
		<cfset keys = arguments.order>
	<cfelse>
		<cfset keys = structKeyList(arguments.data)>
	</cfif>

	<cfif arguments.doroot>
		<cfset s.append("<?xml version=""1.0"" encoding=""UTF-8""?>")>
	</cfif>

	<cfset s.append("<#arguments.rootelement#>")>

	<cfloop index="key" list="#keys#">
		<cfif isSimpleValue(arguments.data[key])>
			<cfset s.append("<#lcase(key)#>#xmlFormat(arguments.data[key])#</#lcase(key)#>")>
		<cfelseif isArray(arguments.data[key])>
			<cfset s.append(arrayToXML(arguments.data[key],lcase(key),false))>
		<cfelse>
			<cfset s.append(structToXML(arguments.data[key],lcase(key),false))>
		</cfif>
	</cfloop>

	<cfset s.append("</#arguments.rootelement#>")>

	<cfreturn s.toString()>
</cffunction>

<cffunction name="upload" access="public" returnType="string" output="false" hint="Uploads a file.">
	<cfargument name="filename" type="string" required="true">
	<cfargument name="description" type="string" required="false">
	<cfargument name="renditions" type="boolean" required="false" default="true">
	<cfargument name="node" type="string" required="false" default="">
    <cfargument name="createpdf" trype="boolean" required="false" default="true">
	<cfset var s = structNew()>
	<cfset var myurl = "POST https://api.acrobat.com/webservices/api/v1/dc/">
	<cfset var response = "">

	<cfif structKeyExists(arguments, "node")>
		<cfset myurl = myurl & arguments.node & "/">
	</cfif>

	<cfset s.file = structNew()>
	<cfset s.file.name = getFileFromPath(arguments.filename)>
	<cfif structKeyExists(arguments, "description")>
		<cfset s.file.description = arguments.description>
	</cfif>
    <cfset s.file.createpdf = arguments.createpdf>
	<cfset response = shareHit(myurl,s,false,arguments.filename)>
	<cfreturn response>
</cffunction>

</cfcomponent>