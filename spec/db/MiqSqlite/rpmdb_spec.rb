require 'db/MiqSqlite/MiqSqlite3'

describe MiqSqlite3DB::MiqSqlite3 do
  let(:fname) { "#{File.dirname(__FILE__)}/rpmdb-empty.sqlite" }
  let(:db)    { MiqSqlite3DB::MiqSqlite3.new(fname) }

  after do
    db.close
  end

  it "#pageSize" do
    expect(db.pageSize).to eq(4_096)
  end

  it "#maxLocal" do
    expect(db.maxLocal).to eq(1_002)
  end

  it "#minLocal" do
    expect(db.minLocal).to eq(489)
  end

  it "#usableSize" do
    expect(db.usableSize).to eq(4_096)
  end

  it "#maxLeaf" do
    expect(db.maxLeaf).to eq(4_061)
  end

  it "#minLeaf" do
    expect(db.minLeaf).to eq(489)
  end

  it "#npages" do
    expect(db.npages).to eq(52)
  end

  it "#each_page" do
    expect(db.each_page { |pg| pg }.count).to eq(52)
  end

  it "#readPage" do
    expect(db.readPage(1)).to start_with("SQLite format 3")
  end

  it "#size" do
    expect(db.size).to eq(File.size(fname))
  end

  it "#table_names" do
    expected = %w[
      Basenames
      Conflictname
      Dirnames
      Enhancename
      Filetriggername
      Group
      Installtid
      Name
      Obsoletename
      Packages
      Providename
      Recommendname
      Requirename
      Sha1header
      Sigmd5
      Suggestname
      Supplementname
      Transfiletriggername
      Triggername
      sqlite_sequence
    ]

    expect(db.table_names).to match_array(expected)
  end

  it "#getTable" do
    packages_table = db.getTable('Packages')

    expect(packages_table).to be_kind_of(MiqSqlite3DB::MiqSqlite3Table)
    expect(packages_table).to have_attributes(
      :name => "Packages",
      :type => "table"
    )
  end
end
