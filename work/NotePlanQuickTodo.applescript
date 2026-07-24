on urlEncode(inputText)
	set pythonCode to "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=''))"
	return do shell script "/usr/bin/python3 -c " & quoted form of pythonCode & " <<< " & quoted form of inputText
end urlEncode

on trimText(inputText)
	return do shell script "/usr/bin/python3 -c " & quoted form of "import sys; print(sys.stdin.read().strip())" & " <<< " & quoted form of inputText
end trimText

on run
	set defaultText to ""
	try
		set defaultText to the clipboard as text
	end try
	set defaultText to my trimText(defaultText)
	
	set answer to display dialog "Texte ou URL a ajouter dans NotePlan :" default answer defaultText buttons {"Annuler", "Todo NotePlan"} default button "Todo NotePlan" cancel button "Annuler" with title "NotePlan Quick Todo"
	set todoText to my trimText(text returned of answer)
	
	if todoText is "" then
		display notification "Aucun texte a envoyer." with title "NotePlan Quick Todo"
		return
	end if
	
	set taskText to "- [ ] " & todoText & " #capture"
	set encodedText to my urlEncode(taskText)
	open location "noteplan://x-callback-url/addText?noteDate=today&text=" & encodedText & "&mode=append&openNote=yes"
	display notification "Todo ajoutee dans NotePlan." with title "NotePlan Quick Todo"
end run
