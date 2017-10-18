require 'fs/MiqFsUtil'
require 'fs/MiqFS/MiqFS'
require 'fs/MetakitFS/MetakitFS'
require 'fs/MiqFS/modules/LocalFS'

require 'logger'
STDERR.sync = true
$log = Logger.new(STDERR)
$log.level = Logger::DEBUG

dobj = OpenStruct.new
dobj.mkfile = ARGV[1]
dobj.create = true

toFs  = MiqFS.new(MetakitFS, dobj)
fromFs  = MiqFS.new(LocalFS, nil)

cf = MiqFsUtil.new(fromFs, toFs, ARGV[0])
cf.verbose = true
cf.update
