-- Pégase · double authentification du compte administrateur
-- À lancer une fois dans Supabase : SQL Editor > New query > coller > Run.
--
-- Le compte administrateur (role 'owner') n'a accès aux données que si sa
-- session a été validée avec Google Authenticator (niveau aal2) depuis moins
-- de 30 jours. Le compte de Catherine (role 'editor') n'est pas concerné.
-- Les mots de passe (« Mes codes ») sont dans la collection 'prive', lisible
-- uniquement par l'administrateur : ils exigent donc eux aussi le code.

create or replace function public.app_role() returns text
language sql stable security definer set search_path = public as $$
  select case
    when a.role = 'owner' and not (
      coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
      and exists (
        select 1
        from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) as m
        where m ->> 'method' = 'totp'
          and (m ->> 'timestamp')::bigint > extract(epoch from now() - interval '30 days')
      )
    ) then null
    else a.role
  end
  from public.allowed a
  where lower(a.email) = lower(auth.jwt() ->> 'email')
$$;

-- En cas de téléphone perdu : Supabase > Authentication > Users > votre compte >
-- supprimer le facteur « Pégase » ; Pégase proposera d'activer un nouveau
-- Google Authenticator à la connexion suivante.
