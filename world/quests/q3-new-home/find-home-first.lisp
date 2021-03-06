(:name find-home-first
 :title "Scout location Beta"
 :description NIL
 :invariant T
 :condition all-complete
 :on-activate (new-home-site-1)
 :on-complete NIL)

;; enemies on this quest will be world NPCs, not spawned for the quest
(quest:interaction :name new-home-site-1 :interactable new-home-1 :dialogue "
~ player
| //It's new-home candidate site Beta.//
| (:thinking) //There could be shelter inside this building.//
| (:normal) //Scanning the interior...//
| //Dirt and sand has intruded through almost every crack.//
| //It's a quicksand deathtrap.//
| Structural integrity can be described as \"may collapse at any moment\".
? (complete-p 'find-home-second 'find-home-third 'find-home-fourth)
| | (:normal) I should return to Jack with the bad news.
| ! eval (activate 'return-new-home)
")
;; TODO: using // on the last line, where it also escapes characters, causes the \\ to render as literals
