# Oderbook

## Description de Oderbook.sol :

Le contrat Oderbook.sol est un contrat qui permet de placer un ordre, annuler un ordre et "remplir" un ordre. Chaque transaction est enregistrée dans un mapping qui permet de retrouver les ordres en fonction de leur id. Une fonction permet d'afficher tous les ordres.

## Description de Oderbook_test.sol :

Le contrat de test est composé de test vérifiant la bonne exécution des fonctions du contrat Oderbook.sol.

Il y a également des test de failures. J'ai fait une fonction de failure par fonction de test, tous les tests de failures test au moins 2 scénarios possible d'échec par fonction.