EinsumPath["ij,jk,kl->il", RandomReal[1, {2, 30}], RandomReal[1, {30, 40}],
   RandomReal[1, {40, 3}]] ===
 EinsumPath["ij,jk,kl->il", {{2, 30}, {30, 40}, {40, 3}}]