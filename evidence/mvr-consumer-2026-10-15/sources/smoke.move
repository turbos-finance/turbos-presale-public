module consumer::smoke { use presale::ido; public fun quote(a: u64,b: u64,d: u64): u64 { ido::mul_div_floor(a,b,d) } }
