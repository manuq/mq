# mq

mis atajos

me da el comando `mq <receta>` que corre las recetas definidas en el
justfile `manuq.just` con [just](https://just.systems), desde
cualquier lugar. también agrega autocompletado para bash.

con `mq` solito se listan las recetas.

correr `./install.sh` para crear enlaces simbólicos desde este repo a
mi home del sistema.

## dependencias

- `just` y `bash` con `~/.bashrc.d/*` configurado en el `~/.bashrc`.

- lo que cada receta use, por ej algunas usan: `gum`, `gh`,
  `ffmpeg`.. etc.
