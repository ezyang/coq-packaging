(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, * CNRS-Ecole Polytechnique-INRIA Futurs-Universite Paris Sud *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(* $Id: command_windows.mli,v 1.1.2.1 2004/07/16 19:30:19 herbelin Exp $ *)

class command_window :
  unit ->
  object
    method new_command : ?command:string -> ?term:string -> unit -> unit
    method window : GWindow.window
  end

val main : unit -> unit

val command_window : unit -> command_window


