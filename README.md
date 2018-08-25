# Yab

Proof of concept blockchain network.

* Lots of tests missing
* Completely insecure since erlang nodes are used for peer communication.
* Extremely rudimentary and naive peer communication
* Keeps full chain in memory with no persistence.
* Coinbase transaction has to be first transaction in block
* Aggressively throws away transactions
* No real identity for transasctions(no timestamp), so one transasction could be incorrecetly applied multiple times


[![asciicast](https://asciinema.org/a/aGZYUAiBlcx8YvmXC3sijhmTm.png)](https://asciinema.org/a/aGZYUAiBlcx8YvmXC3sijhmTm)



