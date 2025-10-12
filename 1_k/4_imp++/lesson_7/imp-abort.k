// Copyright (c) Runtime Verification, Inc. All Rights Reserved.

module IMP-ABORT-SYNTAX
  imports DOMAINS-SYNTAX
  syntax AExp  ::= Int | String | Id
                 | "++" Id
                 | "read" "(" ")"
                 | "-" Int
                 | "(" AExp ")"               [bracket]
                 > AExp "/" AExp              [left, strict]
                 > AExp "+" AExp              [left, strict]
                 > "spawn" Block
                 > Id "=" AExp                [strict(2)]
  syntax BExp  ::= Bool
                 | AExp "<=" AExp             [seqstrict]
                 | "!" BExp                   [strict]
                 | "(" BExp ")"               [bracket]
                 > BExp "&&" BExp             [left, strict(1)]
  syntax Block ::= "{" Stmts "}"
  syntax Stmt  ::= Block
                 | AExp ";"                   [strict]
                 | "if" "(" BExp ")"
                   Block "else" Block         [strict(1)]
                 | "while" "(" BExp ")" Block
                 | "int" Ids ";"
                 | "print" "(" AExps ")" ";"
                 | "halt" ";"
				 | "abort" ";"
                 > "join" AExp ";"            [strict]

  syntax Ids   ::= List{Id,","}               [overload(exps)]
  syntax AExps ::= List{AExp,","}             [overload(exps)]
  syntax Stmts ::= List{Stmt,""}
  syntax AExps ::= Ids
endmodule


module IMP-ABORT
  imports IMP-ABORT-SYNTAX
  imports DOMAINS
  syntax KResult ::= Int | Bool | String

  configuration <T color="yellow">
                  <threads color="orange">
                    <thread multiplicity="*" color="blue" type="Map">
                      <id color="black"> 0 </id>
                      <k color="green"> $PGM:Stmts </k>
                      <env color="LightSkyBlue"> .Map </env>
					  <clean> false </clean>
                    </thread>
                  </threads>
                  <store color="red"> .Map </store>
				  <abort> false </abort>
                  <input color="magenta" stream="stdin"> .List </input>
                  <output color="Orchid" stream="stdout"> .List </output>
                </T>

// AExp
  rule <k> X:Id => I ...</k>
       <env>... X |-> N ...</env>
       <store>... N |-> I ...</store>
	   <abort> false </abort>

  rule <k> ++X => I +Int 1 ...</k>
       <env>... X |-> N ...</env>
       <store>... N |-> (I => I +Int 1) ...</store>
	   <abort> false </abort>

  rule <k> read() => I ...</k>
       <input> ListItem(I:Int) => .List ...</input>
	   <abort> false </abort>

  rule I1 / I2 => I1 /Int I2  requires I2 =/=Int 0
  rule I1 + I2 => I1 +Int I2
  rule - I => 0 -Int I
  rule Str1 + Str2 => Str1 +String Str2
// BExp
  rule I1 <= I2 => I1 <=Int I2
  rule ! T => notBool T
  rule true && B => B
  rule false && _ => false
// Block
  rule <k> {Ss} => Ss ~> Rho ...</k> <env> Rho </env> <abort> false </abort>
  rule <k> Rho => .K ...</k> <env> _ => Rho </env> <abort> false </abort>
// Stmt
  rule _:Int; => .K 
  rule <k> X = I:Int => I ...</k>
       <env>... X |-> N ...</env>
       <store>... N |-> (_ => I) ...</store>
	   <abort> false </abort>

  rule <k> if (true)  S else _ => S </k>
  	   <abort> false </abort>

  rule <k> if (false) _ else S => S </k>
	   <abort> false </abort>

  rule <k> while (B) S => if (B) {S while (B) S} else {.Stmts} </k>
       <abort> false </abort>

  rule <k> int (X,Xs => Xs); ...</k>
       <env> Rho => Rho[X <- !N:Int] </env>
       <store>... .Map => !N |-> 0 ...</store>
	   <abort> false </abort>
  rule int .Ids; => .K

  syntax Printable ::= Int | String
/* currently it is necessary to subsort Printable to AExp,
  but future K should be able to infer that automatically. */
  syntax AExp ::= Printable
  context print(HOLE:AExp, _AEs:AExps);
  rule <k> print(P:Printable,AEs => AEs); ...</k>
       <output>... .List => ListItem(P) </output>
	   <abort> false </abort>
  rule print(.AExps); => .K

  rule <k> halt; ~> _ => .K </k>

  rule <k> abort; ~> _ => .K </k>
       <abort> _ => true </abort>
	   <clean> false => true </clean>

  rule <k> _ => .K </k> 
       <clean> false => true </clean>
  	   <abort> true </abort> 

  rule <k> spawn S => !T:Int +Int 1 ...</k> <env> Rho </env>
       (.Bag => <thread>... <k> S </k> <env> Rho </env> <id> !T +Int 1 </id> ...</thread>)
	   <abort> false </abort>

  rule <k> join(T:Int); => .K ...</k>
       <thread>... <k> .K </k> <id> T </id> ...</thread>
	   <abort> false </abort>

// Stmts
  rule .Stmts => .K
  rule <k> S:Stmt Ss:Stmts => S ~> Ss </k>
	   <abort> false </abort>

// verification ids
  syntax Id ::= "n"     [token]
              | "sum"   [token]
endmodule
