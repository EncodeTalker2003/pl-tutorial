### 1

Just expand the `let*` as multiple `let`s as follows:

```k
rule <k> let* X = E and Bs in E' => let X = E in let* Bs in E' ...</k>

rule <k> let* .Bindings in E => E ...</k>
```

### 2

The easier part is `read`, just treat it as an `Int`.

```k
syntax Exp ::= "read"

rule <k> read => I ...</k>
     <input> ListItem(I:Int) => .List ...</input>
```

For the `print`, here we treat it as a function like `head` and `tail`.

```k
syntax Exp ::= "print" [macro]

syntax Val ::= "printV"
rule print => fun $h -> printV ($h)

rule <k> printV V:Val => V ...</k>
	 <output>... .List => ListItem(V) </output>
```

We would modify the configuration correspondingly 
```k
configuration <T color="yellow">
                  <k color="green"> $PGM:Exp </k>
                  <env color="violet"> .Map </env>
                  <store color="white"> .Map </store>
				  <input color="magenta" stream="stdin"> .List </input>
                  <output color="brown" stream="stdout"> .List </output>
                </T>
```

### 3

We first need to modify the configuration so that it would fit multiple threads.

```k
configuration <T color="yellow">
				  <threads color="orange">
				    <thread multiplicity="*" type="Map" color="yellow">
                      <k color="green"> $PGM:Exp </k>
                      <env color="violet"> .Map </env>
					  <id color="pink"> -1 </id>
					</thread>
                  </threads>
                  <store color="white"> .Map </store>
				  <terminated color="red"> .Set </terminated>
				  <input color="magenta" stream="stdin"> .List </input>
                  <output color="brown" stream="stdout"> .List </output>
                </T>
```

For the `spawn`, we have 
```k
syntax Exp ::= "spawn" Exp

rule <thread>...
         <k> spawn E => !T:Int ...</k>
		 <env> Env </env>
	   ...</thread>
	   ( .Bag => <thread>
	               <k> E </k>
				   <env> Env </env>
				   <id> !T </id>
			     </thread>)
```

For the `join`, we also need to mark which thread has terminated.
```k
syntax Exp ::= "join" Exp                        [strict]
rule (<thread>... 
          <k> _:Val ~> .K </k>
          <id> T </id>
        ...</thread> => .Bag)
       <terminated>... .Set => SetItem(T) ...</terminated>
  
  syntax Val ::= "joinDone"
  rule <k> join T:Int => joinDone ...</k>
       <terminated>... SetItem(T) ...</terminated>
```

Their priority is defined as follows:
```k
syntax priority @__FUN-SPAWN-COMMON
                > apply
                > arith
                > _:=__FUN-SPAWN-COMMON
                > let_in__FUN-SPAWN-COMMON
                  letrec_in__FUN-SPAWN-COMMON
                  if_then_else__FUN-SPAWN-COMMON
				> join__FUN-SPAWN-COMMON
				> spawn__FUN-SPAWN-COMMON
                > _;__FUN-SPAWN-COMMON
                > fun__FUN-SPAWN-COMMON
                > datatype_=___FUN-SPAWN-COMMON
```

### 4

We want formulas to evaluate following statement

```
letrec F1 = E1 and ... and Fn = En in E'
```

To achieve this, we have following definitions:

- Expression tuple: `<E1,E2,...,En>`
- Projection for i-th element of tuple: `proj(i, (E1,E2,...,En)) = Ei` where i=1,...,n

The basic idea is to treat all the `Ei` expressions as a tuple and substitute each `Fi` with the projection of the i-th element of the tuple. However, to do the recursive substitution, we need to define a `mu` operator that allows us to define recursive functions. 

```
let T = mu T -> (E1', E2', ..., En') in
let F1 = proj(1, t) and ... and Fn = proj(n, t) in E'
```

where `Ei'=Ei[F1 |-> proj(1, T), ..., Fn |-> proj(n, T)]`.

Take the following code as an example:

```
letrec
  even = fun x -> if x == 0 then true else odd (x - 1)
and
  odd  = fun x -> if x == 0 then false else even (x - 1)
in
  even 4
```

It would be interpreted as:

```
let T = (mu T -> < fun x -> if x == 0 then true else (proj(2, T)) (x - 1),
                    fun x -> if x == 0 then false else (proj(1, T)) (x - 1) >)
in
  let even = proj(1, T)
  and odd  = proj(2, T)
  in
    even 4
```

However, I could not implement this in current substitution-based FUN definition. This file is too old and many traits are not been supported by K anymore. For example, for the following code 

```k
syntax Case  ::= Exp "->" Exp                    [binder]
``` '
 
If we want to use the `binder` attribute, we need to define the first argument as a `KVar`, which would break the substitution definition. Hope the file would be fixed in future.
