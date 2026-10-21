# Pégase · Domaine Apolo

Le logiciel de gestion du Domaine Apolo (Marrakech) : calendrier, prospects, clients et élèves, offres, argent, chevaux et personnel.

- `index.html` : l'application (page unique).
- `config.js` : l'adresse de la base Supabase et sa clé publique.
- `supabase/setup.sql` : installation de la base (tables, droits d'accès, inscription réservée aux adresses autorisées).

Aucune donnée n'est stockée dans ce dépôt : tout est dans Supabase, protégé par la connexion (e-mail + mot de passe).
Hébergement : Vercel, sans étape de compilation.
