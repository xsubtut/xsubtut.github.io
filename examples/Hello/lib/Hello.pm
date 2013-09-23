package Hello;
use 5.012001;
our $VERSION = '0.01';

require XSLoader;
XSLoader::load('Hello', $VERSION);

1;
