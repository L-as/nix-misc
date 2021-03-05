{ writeScriptBin, coreutils, nix, bubblewrap, ruby }:

writeScriptBin "claybox"
''
#!${coreutils}/bin/env -S ${ruby}/bin/ruby --disable=gems -EUTF-8
# encoding: UTF-8

require "open3"

arity = {
	"--help" => 0,
	"--version" => 0,
	"--args" => 1,
	"--unshare-all" => 0,
	"--share-net" => 0,
	"--unshare-user" => 0,
	"--unshare-user-try" => 0,
	"--unshare-ipc" => 0,
	"--unshare-pid" => 0,
	"--unshare-net" => 0,
	"--unshare-uts" => 0,
	"--unshare-cgroup" => 0,
	"--unshare-cgroup-try" => 0,
	"--userns" => 1,
	"--userns2" => 1,
	"--pidns" => 1,
	"--uid" => 1,
	"--gid" => 1,
	"--hostname" => 1,
	"--chdir" => 1,
	"--setenv" => 2,
	"--unsetenv" => 1,
	"--lock-file" => 1,
	"--sync-fd" => 1,
	"--bind" => 2,
	"--bind-try" => 2,
	"--dev-bind" => 2,
	"--dev-bind-try" => 2,
	"--ro-bind" => 2,
	"--ro-bind-try" => 2,
	"--remount-ro" => 1,
	"--exec-label" => 1,
	"--file-label" => 1,
	"--proc" => 1,
	"--dev" => 1,
	"--tmpfs" => 1,
	"--mqueue" => 1,
	"--dir" => 1,
	"--file" => 2,
	"--bind-data" => 2,
	"--ro-bind-data" => 2,
	"--symlink" => 2,
	"--seccomp" => 1,
	"--block-fd" => 1,
	"--userns-block-fd" => 1,
	"--info-fd" => 1,
	"--json-status-fd" => 1,
	"--new-session" => 0,
	"--die-with-parent" => 0,
	"--as-pid-1" => 0,
	"--cap-add" => 1,
	"--cap-drop" => 1,
}

oargs = ARGV
args = []
paths = []
i = 0
while i < oargs.length do
	case oargs[i]
	when "--nix"
		p = /^(\/nix\/store\/[^\/]*)/.match(File.realpath oargs[i+1])
		if p
			paths << p[1]
		end
		oargs.delete_at(i)
		oargs.delete_at(i)
		next
	when "--bind", "--bind-try", "--dev-bind", "--dev-bind-try", "--ro-bind", "--ro-bind-try"
		begin
			p = /^(\/nix\/store\/[^\/]*)/.match(File.realpath oargs[i+1])
			if p
				paths << p[1]
			end
		rescue
		end
	when "--"
		if oargs[i+1].include? "/" then
			begin
				rp = File.realpath oargs[i+1]
				p = /^(\/nix\/store\/[^\/]*)/.match rp 
				if p
					paths << p[1]
					symlink = "/.executable/#{File.basename oargs[i+1]}"
					oargs[i+1] = symlink
					args.push("--symlink", rp, symlink)
				end
			rescue
			end
		end
		break
	end
	if not arity.include? oargs[i]
		$stderr.write "claybox: Unknown arg #{oargs[i]}\n"
		i += 1
	else
		i += arity[oargs[i]] + 1
	end
end

out, status = Open3.capture2 "${nix}/bin/nix-store", "-qR", *paths
raise "error" unless status.success?
out.split("\n").each {|p|
	args.push("--ro-bind", p, p)
}
exec "${bubblewrap}/bin/bwrap", *args, *oargs
''
