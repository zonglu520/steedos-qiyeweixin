# Qiyeweixin.testSyncCompany()
Qiyeweixin.testSyncCompany = ()->
	# space = db.spaces.findOne({_id: 'qywx-wweee647a39f9efa30'})
	total = db.spaces.find({'services.qiyeweixin.need_sync':true}).count()
	i = 0
	while(i < total)
		i++
		space = db.spaces.findOne({'services.qiyeweixin.need_sync':true})
		Qiyeweixin.syncCompany space

Qiyeweixin.syncCompany = (space)->
	service = space.services.qiyeweixin
	space_id = space._id
	# 根据永久授权码获取access_token
	o = ServiceConfiguration.configurations.findOne({service: "qiyeweixin"})
	at = Qiyeweixin.getCorpToken o.suite_id,o.corpid,service.permanent_code,o.suite_access_token
	# 当下授权的access_token
	if at&&at.access_token
		service.access_token = at.access_token
	# 当前公司下的全部部门，用于删除多余的
	allOrganizations = []
	# 当前公司下的全部用户，用于删除多余的
	allUsers = []
	# 获取部门列表:ok
	orgList = Qiyeweixin.getDepartmentList service.access_token
	# 根据部门列表获取当前部门下的成员信息:ok
	orgList.forEach (org)->
		console.log orgList
		userList = Qiyeweixin.getUserList service.access_token,org.id
		orgUsers = []
		userList.forEach (user)->
			# 管理user表，存在则修改，不存在则新增,并返回user_id
			_id = manageUser user
			# 管理space_user表，，存在则修改，不存在则新增
			user._id = _id
			user.space = space_id
			manageSpaceUser user
			orgUsers.push _id
			allUsers.push _id
		# 部门数据
		org.users = orgUsers
		org._id = space_id + '-' + org.id
		org.fullname = org.name
		org.space = space_id
		org.parent = space_id + '-' + org.parentid
		# 获取当前部门的子部门
		children = orgList.filter((m)->return m.parentid==org.id).map((m)-> return space_id+'-'+m.id)
		org.children = children
		# 根部门-公司
		if org.id == 1
			org.is_company = true
		else
			orgparent = db.organizations.findOne({_id:org.parent},{fullname:1})
			if orgparent && orgparent.fullname
				org.fullname = orgparent.fullname + "/" + org.name
		# 管理organizations表，存在则修改，不存在则新增
		manageOrganizations org
		allOrganizations.push org._id
	# 有问题
	manageSpaces space
	# 当前公司所有的用户和部门，查找如果当前工作区下有多余的用户和部门，则删除
	# console.log '===============所有用户和部门================'
	# console.log allUsers
	# console.log allOrganizations
	# 管理spaces表，增加管理员和拥有者
	


manageSpaces = (space)->
	service = space.services.qiyeweixin
	space_admin_data = Qiyeweixin.getAdminList service.corp_id,service.agentid
	aadmins = []
	space_admin_data.forEach (admin)->
		if admin.auth_type
			admin_user = db.users.findOne({"services.qiyeweixin.id": admin.userid},{_id:1})
			if admin_user
				admins.push admin_user._id
	doc = {}
	doc.admins = admins
	doc.owner = admins[0]
	doc.modified = new Date
	console.log "=============有问题==============="
	console.log doc
	db.spaces.direct.update(space._id, {$set: doc})
manageOrganizations = (organization)->
	org = db.organizations.findOne({_id: organization._id})
	if org
		console.log "修改organizations"
		updateOrganization org,organization
	else
		console.log "新增organizations"
		addOrganization organization
manageSpaceUser = (user)->
	su = db.space_users.findOne({user: user._id})
	if su
		console.log "修改space_users"
		updateSpaceUser su,user
	else
		console.log "新增space_users"
		addSpaceUser user
manageUser = (user)->
	# userid可能也会修改，旧的userid要删除
	u = db.users.findOne({"services.qiyeweixin.id": user.userid})
	userid = ''
	if u
		console.log "修改users"
		userid = u._id
		updateUser u,user
	else
		console.log "新增users"
		userid = addUser user
	return userid
addOrganization = (organization)->
	doc = {}
	doc._id = organization._id
	doc.space = organization.space
	doc.name = organization.name
	doc.fullname = organization.fullname
	if organization.is_company
		doc.is_company = true
	doc.parent = organization.parent
	doc.children = organization.children
	doc.users = organization.users
	doc.sort_no = organization.order
	doc.created = new Date
	doc.modified = new Date 
	db.organizations.direct.insert doc
addSpaceUser = (user)->
	doc = {}
	doc._id = user.space + '-' +user.userid #_id = 工作区id-用户id
	doc.user = user._id
	doc.name = user.name
	doc.space = user.space
	#部门id = 工作区id-部门号
	doc.organizations = user.department.map((m)-> return user.space+"-"+m)
	doc.organization = doc.organizations[0]
	doc.user_accepted = true
	doc.created = new Date
	doc.modified = new Date
	doc.sort_no = user.order[0]
	db.space_users.direct.insert doc
addUser = (user)->
	doc = {}
	doc._id = db.users._makeNewID()
	doc.steedos_id = doc._id
	doc.name = user.name
	doc.avatarURL = user.avatar
	doc.locale = "zh-cn"
	doc.is_deleted = false
	doc.created = new Date
	doc.modified = new Date
	doc.services = {qiyeweixin:{id: user.userid}}
	userid = db.users.direct.insert(doc)
	return userid
updateOrganization = (old_org,new_org)->
	doc = {}
	if old_org.name != new_org.name
		doc.name = new_org.name
		doc.fullname = new_org.fullname
	if old_org.sort_no != new_org.order
		doc.sort_no = new_org.order
	if old_org.parent != new_org.parent
		doc.parent = new_org.parent
	if old_org.users.sort().toString() != new_org.users.sort().toString()
		doc.users = new_org.users
	if old_org.children.sort().toString() != new_org.children.sort().toString()
		doc.children = new_org.children
	console.log doc
	if doc.hasOwnProperty('name') || doc.hasOwnProperty('sort_no') || doc.hasOwnProperty('parent') || doc.hasOwnProperty('users') || doc.hasOwnProperty('children')
		db.organizations.direct.update(old_org._id, {$set: doc})
updateSpaceUser = (old_su,new_su)->
	doc = {}
	if old_su.name != new_su.name
		doc.name = new_su.name
	if old_su.sort_no != new_su.order[0]
		doc.sort_no = new_su.order[0]
	organizations = []
	new_su?.department.forEach (deptid)->
		organizations.push new_su.space + "-" + deptid  #部门id = 工作区id-部门号
	if old_su.organizations.sort().toString() != organizations.sort().toString()
		doc.organizations = organizations
		doc.organization = organizations[0]
	if doc.hasOwnProperty('name') || doc.hasOwnProperty('sort_no') || doc.hasOwnProperty('organization')
		db.space_users.direct.update(old_su._id, {$set: doc})
updateUser = (old_user,new_user)->
	doc = {}
	if old_user.name != new_user.name
		doc.name = new_user.name
	if old_user.avatarURL != new_user.avatar
		doc.avatarURL = new_user.avatar
	if doc.hasOwnProperty('name') || doc.hasOwnProperty('avatarURL')
		doc.modified = new Date
		db.users.direct.update(old_user._id, {$set: doc})

	
