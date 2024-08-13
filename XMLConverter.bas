Attribute VB_Name = "XMLConverter"
'Attribute VB_Name = "XMLConverter"
''
' VBA-XML v0.0.0
' (c) Tim Hall - https://github.com/VBA-tools/VBA-XML
'
' XML Converter for VBA
'
' Design:
' The goal is to have the general form of MSXML2.DOMDocument (albeit not feature complete)
'
' ParseXML(<messages><message id="1">A</message><message id="2">B</message></messages>) ->
'
' {Dictionary}
' - _nodeName: {String} "#document"
' - _attributes: {Dictionary - was Collection} (Nothing)
' - _childNodes: {Collection}
'   {Dictionary}
'   - _nodeName: "messages"
'   - _attributes: (empty)
'   - _childNodes: {Collection}
'     {Dictionary}
'      - _nodeName: "message"
'      - _attributes:
'        {Dictionary - was Collection of Dictionary}
'        "id": "1"
'      - _childNodes: (empty)
'      - _text: A
'     {Dictionary}
'      - _nodeName: "message"
'      - _attributes:
'        {Dictionary - was Collection of Dictionary}
'        "id": "2"
'      - _childNodes: (empty)
'      - _text: B
'
' Errors:
' 10101 - XML parse error
'
' References:
' - http://www.w3.org/TR/REC-xml/
'
' @author: tim.hall.engr@gmail.com
' @license: MIT (http://www.opensource.org/licenses/mit-license.php
'
' Additions by sebastien.kirche@free.fr
' ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ '
Option Explicit

#If Mac Then
#ElseIf VBA7 Then

Private Declare PtrSafe Sub xml_CopyMemory Lib "kernel32" Alias "RtlMoveMemory" _
    (xml_MemoryDestination As Any, xml_MemorySource As Any, ByVal xml_ByteLength As Long)

#Else

Private Declare Sub xml_CopyMemory Lib "kernel32" Alias "RtlMoveMemory" _
    (xml_MemoryDestination As Any, xml_MemorySource As Any, ByVal xml_ByteLength As Long)

#End If

Private Const xml_Html5VoidNodeNames As String = "area|base|br|col|command|embed|hr|img|input|keygen|link|meta|param|source|track|wbr"

' ============================================= '
' Public Methods
' ============================================= '

''
' Convert XML string to Dictionary
'
' @param {String} xml_String
' @return {Object} (Dictionary)
' -------------------------------------- '
Public Function ParseXml(ByVal xml_String As String) As Dictionary
    Dim xml_Index As Long
    xml_Index = 1
    
    ' Remove vbCr, vbLf, and vbTab from xml_String
    xml_String = VBA.Replace(VBA.Replace(VBA.Replace(xml_String, VBA.vbCr, ""), VBA.vbLf, ""), VBA.vbTab, "")
    
    xml_SkipSpaces xml_String, xml_Index
    If VBA.Mid$(xml_String, xml_Index, 1) <> "<" Then
        ' Error: Invalid XML string
        err.Raise 10101, "XMLConverter", xml_ParseErrorMessage(xml_String, xml_Index, "Expecting '<'")
    Else
        Set ParseXml = New Dictionary
        ParseXml.Add "_prolog", xml_ParseProlog(xml_String, xml_Index)
        ParseXml.Add "_doctype", xml_ParseDoctype(xml_String, xml_Index)
        
        ParseXml.Add "_nodeName", "#document"
        ParseXml.Add "_attributes", Nothing
        
        Dim xml_ChildNodes As New Collection
        xml_ChildNodes.Add xml_ParseNode(ParseXml, xml_String, xml_Index)
        ParseXml.Add "_childNodes", xml_ChildNodes
        ParseXml.Add xml_ChildNodes(1)("_nodeName"), xml_ChildNodes(1) ' allow direct access to root element
    End If
End Function

''
' Convert Dictionary to XML
'
' @param {Dictionary} xml_Dictionary
' @return {String}
' -------------------------------------- '
Public Function ConvertToXML(ByVal xml_Dictionary As Dictionary) As String
    Dim xml_buffer As String
    Dim xml_BufferPosition As Long
    Dim xml_BufferLength As Long
    
    ' TODO
End Function

' ============================================= '
' Private Functions
' ============================================= '

Private Function xml_ParseProlog(xml_String As String, ByRef xml_Index As Long) As String
    Dim xml_OpeningLevel As Long
    Dim xml_StringLength As Long
    Dim xml_StartIndex As Long
    Dim xml_Chars As String

    xml_SkipSpaces xml_String, xml_Index
    If VBA.Mid$(xml_String, xml_Index, 2) = "<?" Then
        xml_StartIndex = xml_Index
        xml_Index = xml_Index + 2
        xml_StringLength = Len(xml_String)
    
        ' Find matching closing tag, ?>
        Do
            xml_Chars = VBA.Mid$(xml_String, xml_Index, 2)
            
            If xml_Index + 1 > xml_StringLength Then
                err.Raise 10101, "XMLConverter", xml_ParseErrorMessage(xml_String, xml_Index, "Expecting '?>'")
            ElseIf xml_OpeningLevel = 0 And xml_Chars = "?>" Then
                xml_Index = xml_Index + 2
                Exit Do
            ElseIf xml_Chars = "<?" Then
                xml_OpeningLevel = xml_OpeningLevel + 1
                xml_Index = xml_Index + 2
            ElseIf xml_Chars = "?>" Then
                xml_OpeningLevel = xml_OpeningLevel - 1
                xml_Index = xml_Index + 2
            Else
                xml_Index = xml_Index + 1
            End If
        Loop
        
        xml_ParseProlog = VBA.Mid$(xml_String, xml_StartIndex, xml_Index - xml_StartIndex)
    End If
End Function

Private Function xml_ParseDoctype(xml_String As String, ByRef xml_Index As Long) As String
    Dim xml_OpeningLevel As Long
    Dim xml_StringLength As Long
    Dim xml_StartIndex As Long
    Dim xml_Char As String
    
    xml_SkipSpaces xml_String, xml_Index
    If VBA.Mid$(xml_String, xml_Index, 2) = "<!" Then
        xml_StartIndex = xml_Index
        xml_Index = xml_Index + 2
        xml_StringLength = Len(xml_String)
        
        ' Find matching closing tag, >
        Do
            xml_Char = VBA.Mid$(xml_String, xml_Index, 1)
            xml_Index = xml_Index + 1
            
            If xml_Index > xml_StringLength Then
                err.Raise 10101, "XMLConverter", xml_ParseErrorMessage(xml_String, xml_Index, "Expecting '>'")
            ElseIf xml_OpeningLevel = 0 And xml_Char = ">" Then
                Exit Do
            ElseIf xml_Char = "<" Then
                xml_OpeningLevel = xml_OpeningLevel + 1
            ElseIf xml_Char = ">" Then
                xml_OpeningLevel = xml_OpeningLevel - 1
            End If
        Loop
        
        xml_ParseDoctype = VBA.Mid$(xml_String, xml_StartIndex, xml_Index - xml_StartIndex)
    End If
End Function

Private Function xml_ParseNode(xml_Parent As Dictionary, xml_String As String, ByRef xml_Index As Long) As Dictionary
    Dim xml_StartIndex As Long
    Dim xml_Char As String
    Dim xml_Children As Collection
    Dim xml_StringLength As Long
    Dim xml_elementName As String, xml_closingElement As String

    xml_SkipSpaces xml_String, xml_Index
    If VBA.Mid$(xml_String, xml_Index, 1) <> "<" Then
        err.Raise 10101, "XMLConverter", xml_ParseErrorMessage(xml_String, xml_Index, "Expecting '<'")
    Else
        ' Skip opening bracket
        xml_Index = xml_Index + 1
        
        ' Initialize node
        Set xml_ParseNode = New Dictionary
        xml_ParseNode.Add "_parentNode", xml_Parent
        xml_ParseNode.Add "_attributes", New Dictionary 'Collection
        xml_ParseNode.Add "_childNodes", New Collection
        xml_ParseNode.Add "_text", ""
        xml_ParseNode.Add "_firstChild", Nothing
        xml_ParseNode.Add "_lastChild", Nothing
        
        ' 1. Parse nodeName
        xml_SkipSpaces xml_String, xml_Index
        xml_StartIndex = xml_Index
        xml_StringLength = Len(xml_String)
        
        Do
            DoEvents
            xml_Char = VBA.Mid$(xml_String, xml_Index, 1)
            
            Select Case xml_Char
            Case " ", ">", "/"
                xml_elementName = VBA.Mid$(xml_String, xml_StartIndex, xml_Index - xml_StartIndex)
                xml_ParseNode.Add "_nodeName", xml_elementName
                
                ' Skip space
                If xml_Char = " " Then
                    xml_Index = xml_Index + 1
                End If
                Exit Do
            Case Else
                xml_Index = xml_Index + 1
            End Select
            
            If xml_Index + 1 > xml_StringLength Then
                err.Raise 10101, "XMLConverter", xml_ParseErrorMessage(xml_String, xml_Index, "Expecting ' ', '>', or '/>'")
            End If
        Loop
        
        ' If /> Exit Function
        If VBA.Mid$(xml_String, xml_Index, 2) = "/>" Then
            ' Skip over closing '/>' and exit
            xml_Index = xml_Index + 2
            Exit Function
        ElseIf VBA.Mid$(xml_String, xml_Index, 1) = ">" Then
            ' Skip over '>'
            xml_Index = xml_Index + 1
        Else
            ' 2. Parse attributes
            xml_ParseAttributes xml_ParseNode, xml_String, xml_Index
        End If
        
        ' If /> Exit Function
        If VBA.Mid$(xml_String, xml_Index, 2) = "/>" Then
            ' Skip over closing '/>' and exit
            xml_Index = xml_Index + 2
            Exit Function
        End If
        
        ' 3. Check against known void nodes
        If xml_IsVoidNode(xml_ParseNode) Then
            Exit Function
        End If
        
        ' 4. Parse childNodes
        xml_ParseChildNodes xml_ParseNode, xml_String, xml_Index
        
        'simplify if there is only one child of type text, set it in node
        Set xml_Children = xml_ParseNode.item("_childNodes")
        If xml_Children.Count = 1 Then
            If xml_Children.item(1)("_nodeName") = "#text" Then
                xml_ParseNode.item("_text") = xml_Children.item(1)("_text")
                xml_Children.Remove 1
            End If
        End If
        
        'we should have a closing element else the document is not well-formed
        xml_closingElement = "</" & xml_elementName & ">"
        If VBA.Mid$(xml_String, xml_Index, Len(xml_closingElement)) <> xml_closingElement Then
            err.Raise 10101, "XMLConverter", xml_ParseErrorMessage(xml_String, xml_Index, "Expecting '" & xml_closingElement & "'")
        Else
            xml_Index = xml_Index + Len(xml_closingElement)
        End If
        
    End If
End Function

Private Function xml_ParseAttributes(ByRef xml_Node As Dictionary, xml_String As String, ByRef xml_Index As Long) As Collection
    Dim xml_Char As String
    Dim xml_StartIndex As Long
    Dim xml_StringLength As Long
    Dim xml_Quote As String
    Dim xml_attributes As New Dictionary ' was a collection but duplicated attributes are not allowed
    Dim xml_Name As String
    Dim xml_Value As String
    
    xml_SkipSpaces xml_String, xml_Index
    xml_StartIndex = xml_Index
    xml_StringLength = Len(xml_String)
    
    Do
        xml_Char = VBA.Mid$(xml_String, xml_Index, 1)
        
        Select Case xml_Char
        Case "="
            ' Found end of attribute name
            ' Extract name, skip =, reset start index, and check for quote
            xml_Name = VBA.Mid$(xml_String, xml_StartIndex, xml_Index - xml_StartIndex)
            
            xml_Index = xml_Index + 1
            
            ' Check quote style of attribute value
            xml_Char = VBA.Mid$(xml_String, xml_Index, 1)
            If xml_Char = """" Or xml_Char = "'" Then
                xml_Quote = xml_Char
                xml_Index = xml_Index + 1
            End If
            
            xml_StartIndex = xml_Index
        Case xml_Quote, " ", ">", "/"
            If xml_Char = "/" And VBA.Mid$(xml_String, xml_Index, 2) <> "/>" Then
                ' It's just a simple escape
                xml_Index = xml_Index + 1
            Else
                If xml_Name <> "" Then
                    ' Attribute name was stored, end of attribute value
                    xml_Value = VBA.Mid$(xml_String, xml_StartIndex, xml_Index - xml_StartIndex)
                    
                    ' Store name: value
                    xml_attributes.Add xml_Name, xml_Value
                End If
                
                If xml_Char = ">" Or xml_Char = "/" Then
                    xml_Index = xml_Index + 1
                    Exit Do
                Else
                    xml_Name = ""
                    xml_Value = ""
                    
                    xml_Index = xml_Index + 1
                    xml_SkipSpaces xml_String, xml_Index
                    xml_StartIndex = xml_Index
                End If
            End If
        Case Else
            xml_Index = xml_Index + 1
        End Select
        
        If xml_Index > xml_StringLength Then
            err.Raise 10101, "XMLConverter", xml_ParseErrorMessage(xml_String, xml_Index, "Expecting '>' or '/>'")
        End If
    Loop
    
    Set xml_Node("_attributes") = xml_attributes
End Function

Private Function xml_ParseChildNodes(ByRef xml_Node As Dictionary, xml_String As String, ByRef xml_Index As Long) As Collection
    Dim xml_Char As String
    Dim xml_Children As Collection
    Dim xml_Child As Dictionary
    Dim xml_StartIndex As Long
    Dim xml_StringLength As Long
    Dim xml_ParentClosing As String
    
    Set xml_Children = xml_Node("_childNodes")
    xml_StartIndex = xml_Index
    xml_StringLength = Len(xml_String)
    xml_ParentClosing = "</" & xml_Node.item("_nodeName") & ">"
       
    Do
        xml_Char = VBA.Mid$(xml_String, xml_Index, 1)
        Select Case xml_Char
            Case "<"
                ' store the text if any
                If xml_Index > xml_StartIndex Then
                    Set xml_Child = New Dictionary
                    xml_Child.Add "_parentNode", xml_Node
                    xml_Child.Add "_nodeName", "#text"
                    xml_Child.Add "_text", VBA.Mid$(xml_String, xml_StartIndex, xml_Index - xml_StartIndex)
                    xml_Child.Add "_attributes", Nothing
                    xml_Child.Add "_childNodes", Nothing
                    
                    xml_Node.item("_childNodes").Add xml_Child
                    'xml_addSequencedChild xml_Node, xml_Child
                    xml_StartIndex = xml_Index
                End If
                'closing tag of child ?
                If VBA.Mid$(xml_String, xml_Index, 2) = "</" Then
                    ' closing tag check
                    If VBA.Mid$(xml_String, xml_Index, Len(xml_ParentClosing)) <> xml_ParentClosing Then
                        err.Raise 10101, "XMLConverter", xml_ParseErrorMessage(xml_String, xml_Index, "Unablanced closing tag, expecting '" & xml_ParentClosing & "'")
                    Else
                        Exit Function
                    End If
                    xml_StartIndex = xml_Index
                Else
                    ' child
                    Set xml_Child = xml_ParseNode(xml_Node, xml_String, xml_Index)
                    'xml_Children.Add xml_Child
                    xml_addSequencedChild xml_Node, xml_Child
                    xml_StartIndex = xml_Index
                End If
                
            Case Else
                xml_Index = xml_Index + 1
        End Select
        If xml_Index > xml_StringLength Then
            err.Raise 10101, "XMLConverter", xml_ParseErrorMessage(xml_String, xml_Index, "Expecting '<'")
        End If
    Loop
    
End Function

' Add a child to a parent in its _childNodes collection
' but add it also in its Dictionary to allow "direct" access
' the first time we have no way to tell if it will be alone
' but if the child name is repeated add it as a sequence
Private Sub xml_addSequencedChild(xml_Node As Dictionary, xml_Child As Dictionary)
    Dim existingChild As Dictionary
    Dim last_elem As Long
    Dim childName As String
    childName = xml_Child("_nodeName")
    
    If xml_Node.Exists("_" & childName & "_last") Then
        last_elem = xml_Node("_" & childName & "_last")
        last_elem = last_elem + 1
        xml_Child.Add "_index", last_elem
        xml_Node.Add childName & "#" & CStr(last_elem), xml_Child ' add first for direct access
        xml_Node.item("_childNodes").Add xml_Child ' add in the children collection
        xml_Node.item("_" & childName & "_last") = last_elem ' keep last index
    Else
        If xml_Node.Exists(childName) Then
            'adding a duplicate
            Set existingChild = xml_Node(childName)
            xml_Node.Remove childName ' remove direct access
            existingChild.Add "_index", 1
            xml_Node.Add childName & "#" & CStr(1), existingChild ' add previous with new name = rename
            xml_Child.Add "_index", 2
            xml_Node.Add childName & "#" & CStr(2), xml_Child ' add first for direct access
            xml_Node.Add "_" & childName & "_last", 2 ' keep last index
            xml_Node.item("_childNodes").Add xml_Child ' add in the children collection
        Else
            xml_Node.Add childName, xml_Child ' add first for direct access
            xml_Node.item("_childNodes").Add xml_Child ' add in the children collection
        End If
    End If

End Sub

Private Function xml_IsVoidNode(xml_Node As Dictionary) As Boolean
    ' xml_HTML5VoidNodeNames
    ' TODO xml_VoidNode = Check doctype for html: xml_RootNode("doctype")...
End Function

Private Function xml_ProcessString(xml_String As String) As String
    Dim xml_buffer As String
    Dim xml_BufferPosition As Long
    Dim xml_BufferLength As Long
    Dim xml_Index As Long
    
    ' TODO
    xml_BufferAppend xml_buffer, xml_String, xml_BufferPosition, xml_BufferLength
    xml_ProcessString = xml_BufferToString(xml_buffer, xml_BufferPosition, xml_BufferLength)
End Function

Private Function xml_RootNode(xml_Node As Dictionary) As Dictionary
    Set xml_RootNode = xml_Node
    Do While Not xml_RootNode.Exists("parentNode")
        Set xml_RootNode = xml_RootNode.item("parentNode")
    Loop
End Function

Private Sub xml_SkipSpaces(xml_String As String, ByRef xml_Index As Long)
    ' Increment index to skip over spaces
    Do While xml_Index > 0 And xml_Index <= VBA.Len(xml_String) And VBA.Mid$(xml_String, xml_Index, 1) = " "
        xml_Index = xml_Index + 1
    Loop
End Sub

Private Function xml_StringIsLargeNumber(xml_String As Variant) As Boolean
    ' Check if the given string is considered a "large number"
    ' (See xml_ParseNumber)
    
    Dim xml_Length As Long
    xml_Length = VBA.Len(xml_String)
    
    ' Length with be at least 16 characters and assume will be less than 100 characters
    If xml_Length >= 16 And xml_Length <= 100 Then
        Dim xml_CharCode As String
        Dim xml_Index As Long
        
        xml_StringIsLargeNumber = True
        
        For i = 1 To xml_Length
            xml_CharCode = VBA.asc(VBA.Mid$(xml_String, i, 1))
            Select Case xml_CharCode
            ' Look for .|0-9|E|e
            Case 46, 48 To 57, 69, 101
                ' Continue through characters
            Case Else
                xml_StringIsLargeNumber = False
                Exit Function
            End Select
        Next i
    End If
End Function

Private Function xml_ParseErrorMessage(xml_String As String, ByRef xml_Index As Long, xml_ErrorMessage As String)
    ' Provide detailed parse error message, including details of where and what occurred
    '
    ' Example:
    ' Error parsing XML:
    ' <abc>1234</def>
    '          ^
    ' Expecting '</abc>'
    
    Dim xml_StartIndex As Long
    Dim xml_StopIndex As Long
    
    ' Include 10 characters before and after error (if possible)
    xml_StartIndex = xml_Index - 10
    xml_StopIndex = xml_Index + 10
    If xml_StartIndex <= 0 Then
        xml_StartIndex = 1
    End If
    If xml_StopIndex > VBA.Len(xml_String) Then
        xml_StopIndex = VBA.Len(xml_String)
    End If

    xml_ParseErrorMessage = "Error parsing XML:" & VBA.vbNewLine & _
        VBA.Mid$(xml_String, xml_StartIndex, xml_StopIndex - xml_StartIndex + 1) & VBA.vbNewLine & _
        VBA.Space$(xml_Index - xml_StartIndex) & "^" & VBA.vbNewLine & _
        xml_ErrorMessage
End Function

Private Sub xml_BufferAppend(ByRef xml_buffer As String, _
    ByRef xml_Append As Variant, _
    ByRef xml_BufferPosition As Long, _
    ByRef xml_BufferLength As Long)

#If Mac Then
    xml_buffer = xml_buffer & xml_Append
#Else
    ' VBA can be slow to append strings due to allocating a new string for each append
    ' Instead of using the traditional append, allocate a large empty string and then copy string at append position
    '
    ' Example:
    ' Buffer: "abc  "
    ' Append: "def"
    ' Buffer Position: 3
    ' Buffer Length: 5
    '
    ' Buffer position + Append length > Buffer length -> Append chunk of blank space to buffer
    ' Buffer: "abc       "
    ' Buffer Length: 10
    '
    ' Copy memory for "def" into buffer at position 3 (0-based)
    ' Buffer: "abcdef    "
    '
    ' Approach based on cStringBuilder from vbAccelerator
    ' http://www.vbaccelerator.com/home/VB/Code/Techniques/RunTime_Debug_Tracing/VB6_Tracer_Utility_zip_cStringBuilder_cls.asp

    Dim xml_AppendLength As Long
    Dim xml_LengthPlusPosition As Long
    
    xml_AppendLength = VBA.LenB(xml_Append)
    xml_LengthPlusPosition = xml_AppendLength + xml_BufferPosition
    
    If xml_LengthPlusPosition > xml_BufferLength Then
        ' Appending would overflow buffer, add chunks until buffer is long enough
        Dim xml_TemporaryLength As Long
        
        xml_TemporaryLength = xml_BufferLength
        Do While xml_TemporaryLength < xml_LengthPlusPosition
            ' Initially, initialize string with 255 characters,
            ' then add large chunks (8192) after that
            '
            ' Size: # Characters x 2 bytes / character
            If xml_TemporaryLength = 0 Then
                xml_TemporaryLength = xml_TemporaryLength + 510
            Else
                xml_TemporaryLength = xml_TemporaryLength + 16384
            End If
        Loop
        
        xml_buffer = xml_buffer & VBA.Space$((xml_TemporaryLength - xml_BufferLength) \ 2)
        xml_BufferLength = xml_TemporaryLength
    End If
    
    ' Copy memory from append to buffer at buffer position
    xml_CopyMemory ByVal xml_UnsignedAdd(StrPtr(xml_buffer), _
        xml_BufferPosition), _
        ByVal StrPtr(xml_Append), _
        xml_AppendLength
    
    xml_BufferPosition = xml_BufferPosition + xml_AppendLength
#End If
End Sub

Private Function xml_BufferToString(ByRef xml_buffer As String, ByVal xml_BufferPosition As Long, ByVal xml_BufferLength As Long) As String
#If Mac Then
    xml_BufferToString = xml_buffer
#Else
    If xml_BufferPosition > 0 Then
        xml_BufferToString = VBA.Left$(xml_buffer, xml_BufferPosition \ 2)
    End If
#End If
End Function

#If VBA7 Then
Private Function xml_UnsignedAdd(xml_Start As LongPtr, xml_Increment As Long) As LongPtr
#Else
Private Function xml_UnsignedAdd(xml_Start As Long, xml_Increment As Long) As Long
#End If

    If xml_Start And &H80000000 Then
        xml_UnsignedAdd = xml_Start + xml_Increment
    ElseIf (xml_Start Or &H80000000) < -xml_Increment Then
        xml_UnsignedAdd = xml_Start + xml_Increment
    Else
        xml_UnsignedAdd = (xml_Start + &H80000000) + (xml_Increment + &H80000000)
    End If
End Function

Sub xml_showNodePart(node As Dictionary, key As String, indentLevel As Integer)
    Dim indent As String
    indent = String(indentLevel * 2, " ")
    
    If node.Exists(key) Then
        If node.item(key) <> "" Then
            Debug.Print indent & "- " & key & ": (" & TypeName(node.item(key)) & ") """ & node(key) & """"
        End If
    End If
End Sub
Sub xml_showNode(node As Dictionary, Optional indentLevel As Integer = 0)
    
    Dim k As Variant
    Dim i As Long
    Dim indent As String
    indent = String(indentLevel * 2, " ")
    
    Dim attrs As Dictionary, childs As Collection
    Debug.Print indent & "{" & TypeName(node) & "}"
    xml_showNodePart node, "_nodeName", indentLevel
    xml_showNodePart node, "_text", indentLevel
    
    Set attrs = node("_attributes")
    If Not attrs Is Nothing Then
        If attrs.Count > 0 Then
            Debug.Print indent & "- _attributes: {Dictionary} " & attrs.Count & " item(s)"
            For Each k In attrs.Keys
                Debug.Print indent & indent & "- """ & k & """: """ & attrs.item(k) & """"
            Next
        End If
    Else
        Debug.Print indent & "- _attributes: (empty)"
    End If
    
    For Each k In node.Keys
        Select Case k
            Case "_nodeName", "_text", "_attributes", "_parentNode", _
                 "_childNodes", "_firstChild", "_lastChild", "_index"
                'nothing, ignore this element
            Case Else:
                Select Case TypeName(node(k))
                    Case "Integer", "Long":
                        Debug.Print indent & "- " & k & " (" & TypeName(node(k)) & ") " & CStr(node(k))
                    Case Else:
                        Debug.Print indent & "- " & k & " (" & TypeName(node(k)) & ")"
                    End Select
        End Select
    Next
    
    Set childs = node("_childNodes")
    If Not childs Is Nothing Then
        If childs.Count > 0 Then
            Debug.Print indent & "- _childNodes: {Collection} " & childs.Count & " item(s)"
            If childs.Count > 0 Then
                For i = 1 To childs.Count
                    xml_showNode childs.item(i), indentLevel + 1
                Next
            End If
        End If
    Else
        Debug.Print indent & "- _childNodes: (empty)"
    End If
End Sub

Sub xml_testLib()
    Dim d As Dictionary
    Set d = New Dictionary
    d.Add "foo", "bar"
    d.Add "baz", 42
    
    Debug.Print ConvertToXML(d)
    
    Dim x As String
    'x = "<foo>sometext</foo>"
    'x = "<foo><bar>sometext</bar></foo>"
    'x = "<foo><bar>sometext<other/>text2</bar></foo>"
    x = "<messages><message id=""1"">A</message><message id=""2"">B</message></messages>"
    'Set d = ParseXml(x)
    'xml_showNode d
    
    'End
    
    Dim XML As Object
    Set XML = XMLConverter.ParseXml( _
    "<?xml version=""1.0""?>" & _
      "<messages>" & _
        "<message id=""1"" date=""2014-1-1"">" & _
          "<from><name>Tim Hall</name></from>" & _
          "<body>Howdy!</body>" & _
        "</message>" & _
        "<message id=""2"" date=""2014-1-1"">" & _
          "<from><name>John Doe</name></from>" & _
          "<body>Hello, World!<signature>ident1</signature></body>" & _
        "</message>" & _
      "</messages>" _
    )

    xml_showNode XML

    'Debug.Print XML("#document")("nodeName") ' -> "messages"
    Debug.Print XML("_childNodes")(1)("_childNodes")(1)("_attributes")("id") ' -> "1"
    Debug.Print XML("messages")("message#1")("_attributes")("id")
    Debug.Print XML("_childNodes")(1)("_childNodes")(1)("_attributes")("date") ' -> "2014-1-1"
    Debug.Print XML("messages")("message#2")("_attributes")("date")
    Debug.Print XML("_childNodes")(1)("_childNodes")(1)("_childNodes")(2)("_text") ' -> "Howdy!"
    'Debug.Print XML("messages")("message")("body")("_text")
    Debug.Print XML("messages")("message#2")("body")("_childNodes")(1)("_text") ' -> "Hello, World!"

    Debug.Print XMLConverter.ConvertToXML(XML)
    
End Sub

