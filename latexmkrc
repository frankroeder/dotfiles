if ($^O eq 'darwin') {
  $pdf_previewer = 'open -a sioyek';
} else {
  $pdf_previewer = 'zathura';
}
$pdf_mode = 4;
$out_dir = 'build/';
@generated_exts = (@generated_exts, 'synctex.gz');
