open A_normalizer;;
open OUnit2;;

let new_test_context () =
  new_a_normalization_context ~prefix:"var" ()
;;

let assert_equal_ast expected actual =
  assert_equal ~printer:Pprintast.string_of_expression expected actual
;;

let ident_test _ =
  let context = new_test_context () in
  let e  = [%expr v] in
  let expected = [%expr v] in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let constant_test _ =
  let context = new_test_context () in
  let e = [%expr 4] in
  let expected = [%expr 4] in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let tuple_test_1 _ =
  let context = new_test_context () in
  let e = [%expr (2,3)] in
  let expected =
    [%expr let var0 = 2 in
      let var1 = 3 in
      (var0, var1)] in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let tuple_test_2 _ =
  let context = new_test_context () in
  let e = [%expr ((2,3), 1)] in
  let expected =
    [%expr let var2 =
             (let var0 = 2 in
              let var1 = 3 in
              (var0, var1)) in
      let var3 = 1 in
      (var2, var3)] in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let construct_test_1 _ =
  let context = new_test_context () in
  let e = [%expr C] in
  let expected = [%expr C] in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let construct_test_2 _ =
  let context = new_test_context () in
  let e = [%expr true] in
  let expected = [%expr true] in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let construct_test_3 _ =
  let context = new_test_context () in
  let e = [%expr C 4] in
  let expected = [%expr let var0 = 4 in C var0] in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let construct_test_4 _ =
  let context = new_test_context () in
  let e = [%expr C1 ('a', 5, C2 4)] in
  let expected =
    [%expr
      let var4 =
        let var1 = 'a' in
        let var2 = 5 in
        let var3 =
          let var0 = 4 in
          C2 var0
        in (var1, var2, var3)
      in
      C1 var4
    ]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let let_test_1 _ =
  let context = new_test_context () in
  let e = [%expr let x = 4 in x] in
  let expected = [%expr let x = 4 in x] in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let let_test_2 _ =
  let context = new_test_context () in
  let e = [%expr let x = C 4 in x] in
  let expected =
    [%expr let x = let var0 = 4 in C var0 in x] in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let let_test_3 _ =
  let context = new_test_context () in
  let e = [%expr let x = C 4 in ('a', x)] in
  let expected =
    [%expr
      let x =
        let var0 = 4 in
        C var0
      in
      let var1 = 'a' in
      let var2 = x in
      (var1, var2)] in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let let_test_4 _ =
  let context = new_test_context () in
  let e =
    [%expr let x =
             (let y = 3 in ('a', y)) in
      C x] in
  let expected =
    [%expr
      let x =
        let y = 3 in
        let var0 = 'a' in
        let var1 = y in
        (var0, var1)
      in
      let var2 = x  in C var2
    ] in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let fun_test_1 _ =
  let context = new_test_context () in
  let e =
    [%expr fun x -> (x, 4)] in
  let expected =
    [%expr fun x -> (let var0 = x in let var1 = 4 in (var0, var1))]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let fun_test_2 _ =
  let context = new_test_context () in
  let e =
    [%expr fun x -> fun y -> (x,y)] in
  let expected =
    [%expr fun x -> fun y -> (let var0 = x in let var1 = y in (var0, var1))]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let fun_test_3 _ =
  let context = new_test_context () in
  let e =
    [%expr fun x y -> (x, y)] in
  let expected =
    [%expr fun x -> fun y -> (let var0 = x in let var1 = y in (var0, var1))]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let fun_test_4 _ =
  let context = new_test_context () in
  let e =
    [%expr fun ~l:x y -> (x, y)] in
  let expected =
    [%expr fun ~l:x -> fun y ->
      (let var0 = x in let var1 = y in (var0, var1))]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let fun_test_5 _ =
  let context = new_test_context () in
  let e =
    [%expr fun ?l:(x = 0) y -> (x, y)] in
  let expected =
    [%expr fun ?l:(x = 0) y ->
      let var0 = x in let var1 = y in (var0, var1)]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let fun_test_6 _ =
  let context = new_test_context () in
  let e =
    [%expr fun ?l:(x = (0, 1)) y -> (x, y)] in
  let expected =
    [%expr fun
      ?l:(x = let var0 = 0 in let var1 = 1 in (var0, var1)) ->
      fun y ->
        let var2 = x in let var3 = y in (var2, var3)]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let function_test_1 _ =
  let context = new_test_context () in
  let e =
    [%expr function x -> (x, 2)] in
  let expected =
    [%expr function x -> let var0 = x in let var1 = 2 in (var0, var1)]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let function_test_2 _ =
  let context = new_test_context () in
  let e =
    [%expr function
        Foo x -> x + 1
      | Bar x -> x - 1] in
  let expected =
    [%expr function
        Foo x -> let var0 = (+) in let var1 = x in let var2 = 1 in
        var0 var1 var2
      | Bar x -> let var3 = (-) in let var4 = x in let var5 = 1 in
        var3 var4 var5]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let function_test_3 _ =
  let context = new_test_context () in
  let e =
    [%expr function
        x when (x > 0) -> x
      | x -> 0] in
  let expected =
    [%expr function
        x when (let var0 = (>) in
                let var1 = x in
                let var2 = 0 in
                var0 var1 var2) -> x
      | x -> 0]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let apply_test_1 _ =
  let context = new_test_context () in
  let e =
    [%expr f 5] in
  let expected =
    [%expr
      let var0 = f in
      let var1 = 5 in
      var0 var1]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let apply_test_2 _ =
  let context = new_test_context () in
  let e =
    [%expr (function x -> (x, 4)) 'a'] in
  let expected =
    [%expr let var2 =
             (function x -> let var0 = x in
                let var1 = 4 in
                (var0, var1)) in
      let var3 = 'a' in
      var2 var3]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let apply_test_3 _ =
  let context = new_test_context () in
  let e =
    [%expr (fun ~l:x y -> (x, y)) ~l:5 4] in
  let expected = [%expr let var2 =
                          (fun ~l:x ->
                             fun y ->
                               let var0 = x in
                               let var1 = y in
                               (var0, var1)) in
    let var3 = 5 in
    let var4 = 4 in
    var2 ~l:var3 var4]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let apply_test_4 _ =
  let context = new_test_context () in
  let e =
    [%expr (fun ?l:(x = 0) y -> (x, y)) ~l:1 2] in
  let expected =
    [%expr let var2 =
             (fun ?l:(x = 0) ->
                fun y ->
                  let var0 = x in let var1 = y in (var0, var1)) in
      let var3 = 1 in
      let var4 = 2 in
      var2 ~l:var3 var4]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let match_test_1 _ =
  let context = new_test_context () in
  let e = [%expr
    match a with
    | Foo x -> 1
    | Bar x -> 0] in
  let expected = [%expr
    match a with
    | Foo x -> 1
    | Bar x -> 0]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let match_test_2 _ =
  let context = new_test_context () in
  let e =
    [%expr match a with
      | Foo x -> x + 1
      | Bar x -> x] in
  let expected =
    [%expr
      match a with
      | Foo x ->
        let var0 = (+) in
        let var1 = x in
        let var2 = 1 in
        var0 var1 var2
      | Bar x -> x]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let ifthenelse_test_1 _ =
  let context = new_test_context () in
  let e = [%expr if true then 3 else 4] in
  let expected =
    [%expr let var0 = true in if var0 then 3 else 4] in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let ifthenelse_test_2 _ =
  let context = new_test_context () in
  let e = [%expr if x then f 0 else 0] in
  let expected =
    [%expr let var0 = x in
      if var0
      then
        (let var1 = f in
         let var2 = 0 in
         var1 var2)
      else
        0]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let field_test_1 _ =
  let context = new_test_context () in
  let e = [%expr x.f] in
  let expected = [%expr let var0 = x in var0.f] in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let field_test_2 _ =
  let context = new_test_context () in
  let e = [%expr x.f1.f2] in
  let expected =
    [%expr let var1 =
             let var0 = x in var0.f1 in
      var1.f2] in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let record_test_1 _ =
  let context = new_test_context () in
  let e = [%expr {foo = x; bar = y}] in
  let expected =
    [%expr let var0 = x in
      let var1 = y in
      {foo = var0; bar = var1}]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let record_test_2 _ =
  let context = new_test_context () in
  let e = [%expr {foo = C 10; bar = x + 5}] in
  let expected =
    [%expr
      let var4 =
        let var0 = 10 in
        C var0
      in
      let var5 =
        let var1 = (+) in
        let var2 = x in
        let var3 = 5 in
        var1 var2 var3
      in
      { foo = var4; bar = var5; }
    ]
  in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

(*TODO: test pexp_try*)

let try_test_1 _ =
  let context = new_test_context () in
  let e = [%expr
    try
      5
    with
    | _ -> 6
  ] in
  let expected = [%expr
    try
      5
    with
    | _ -> 6
  ] in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let try_test_2 _ =
  let context = new_test_context () in
  let e = [%expr
    try
      (4,5)
    with
    | _ -> (6,7)] in
  let expected = [%expr
    try
      let var0 = 4 in
      let var1 = 5 in
      (var0, var1)
    with
    | _ ->
      let var2 = 6 in
      let var3 = 7 in
      (var2, var3)
  ] in
  assert_equal_ast expected (a_translate ~context:(Some context) e)
;;

let tests = "a_translate" >::: [

    "ident test" >:: ident_test;
    "constant test" >:: constant_test;
    "tuple test 1" >:: tuple_test_1;
    "tuple test 2" >:: tuple_test_2;
    "construct test 1" >:: construct_test_1;
    "construct test 2" >:: construct_test_2;
    "construct test 3" >:: construct_test_3;
    "construct test 4" >:: construct_test_4;
    "let test 1" >:: let_test_1;
    "let test 2" >:: let_test_2;
    "let test 3" >:: let_test_3;
    "let test 4" >:: let_test_4;
    "fun test 1" >:: fun_test_1;
    "fun test 2" >:: fun_test_2;
    "fun test 3" >:: fun_test_3;
    "fun test 4" >:: fun_test_4;
    "fun test 5" >:: fun_test_5;
    "fun test 6" >:: fun_test_6;
    "function test 1" >:: function_test_1;
    "function test 2" >:: function_test_2;
    "function test 3" >:: function_test_3;
    "apply test 1" >:: apply_test_1;
    "apply test 2" >:: apply_test_2;
    "apply test 3" >:: apply_test_3;
    "apply test 4" >:: apply_test_4;
    "match test 1" >:: match_test_1;
    "match test 2" >:: match_test_2;
    "ifthenelse test 1" >:: ifthenelse_test_1;
    "ifthenelse test 2" >:: ifthenelse_test_2;
    "field test 1" >:: field_test_1;
    "field test 2" >:: field_test_2;
    "record test 1" >:: record_test_1;
    "record test 2" >:: record_test_2;
    "try test 1" >:: try_test_1;
    "try test 2" >:: try_test_2;

  ]
;;
