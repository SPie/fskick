# FSKick

## 1. Spiele
  * Spiele werden bis 10 gespielt.
  * Bei weniger als 2 Toren Unterschied wird so lange gespielt, bis der Unterschied hergestellt ist.
  
## 2. Tagessiege
  * In die Tabelle wird ein Tagessieg als Spiel eingetragen.
  * Den Tagessieg bekommt das Team mit den meisten gewonnenen Spielen.
  * Bei Unentschieden in Spielen, entscheidet das Torverhältniss.
  * Wenn auch das Torverhältniss ausgeglichen ist, wird beiden Teams ein Sieg angerechnet.  

## 3. Tabelle
  * Die Punkte ergeben sich aus dem Verhältnis aus dem dreifachen der Anzahl der Siege und der Anzahl der Spiele.
  ```WINS * 3 / GAMES```
  * Wenn ein Spieler oder eine Spielerin weniger als die Hälfte der Anzahl der Spiele des Spielers oder der Spielerin mit den meisten Spielen hat, werden die Siege im Verhältnis zur Hälfte der Spiele dieses Spielers oder dieser Spielerin gewertet.
 ```WINS * 3 / MAX(GAMES, (MAX_PLAYER_GAMES / 2))```

