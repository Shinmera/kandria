(:identifier quest :version world-v0)
(:name test :author "Nicolas Hafner"
 :title "Example quest" :description "An example quest for the demo."
 :on-activate (inspect-camp)
 :tasks (#p"task-1.lisp"))
