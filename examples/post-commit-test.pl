EGIN {
    $ENV{ MUS_DEBUG } = 1;
    $ENV{ MUS_LOG_TRUNCATE } = 1;
}

use strict;
system( 'post-commit.bat D:\svn\repos\sample 131 unused ' );
